import shlex
import subprocess
import json
import time
from typing import Dict

from cloud.aws.templates.aws_oidc.bin import resources
from cloud.shared.bin.lib.config_loader import ConfigLoader
from cloud.shared.bin.lib.print import print


class AwsCli:
    """Wrapper class that encapsulates calls to AWS CLI."""

    def __init__(self, config: ConfigLoader):
        self.config: ConfigLoader = config
        self._ecs_cluster = f"{config.app_prefix}-{resources.CLUSTER}"
        self._ecs_service = f"{config.app_prefix}-{resources.FARGATE_SERVICE}"

    def get_secret_value(self, secret_name: str) -> str:
        res = self._call_cli(
            f"secretsmanager get-secret-value --secret-id={secret_name}")
        return res["SecretString"]

    def is_secret_empty(self, secret_name: str) -> bool:
        return self.get_secret_value(secret_name).strip() == ""

    def is_db_password_default(self, secret_name: str) -> bool:
        return self.get_secret_value(secret_name).startswith("default-")

    def set_secret_value(self, secret_name: str, new_value: str):
        self._call_cli(
            f"secretsmanager update-secret --secret-id={secret_name} --secret-string={new_value}"
        )

    def get_current_user(self) -> str:
        res = self._call_cli("sts get-caller-identity")
        return res["UserId"]

    def update_master_password_in_database(self, db_name: str, password: str):
        self._call_cli(
            f"rds modify-db-instance --db-instance-identifier={db_name} --master-user-password={password} "
        )

    def restart_ecs_service(self):
        """
        Restarts the CiviForm ECS service.
        """
        self._call_cli(
            f"ecs update-service --force-new-deployment --cluster={self._ecs_cluster} --service={self._ecs_service}"
        )

    def wait_for_ecs_service_healthy(self):
        """
        Polls the CiviForm ECS service, waiting for the PRIMARY deployment to
        have rolloutStatus of COMPLETED.

        Gives up after 20 tries, sleeps 30 seconds between each try.
        """
        print(
            "\nWaiting for CiviForm ECS service to become healthy.\n"
            f"Service URL: {self._get_url_of_ecs_service()}")

        tries = 20
        while True:
            state = self._ecs_service_state()
            if state == "COMPLETED":
                print("Service is healthy.")
                return

            tries -= 1
            if tries == 0:
                print(
                    "\nERROR: service did not become healthy in expected amount of time. This usually means the new tasks are crash-looping.\n"
                    "To see the task logs, follow https://docs.civiform.us/it-manual/sre-playbook/terraform-deploy-system/terraform-aws-deployment#inspecting-logs\n"
                    "For debugging help, contact the CiviForm oncall: https://docs.civiform.us/governance-and-management/project-management/on-call-guide#on-call-responsibilities"
                )
                raise Exception(
                    "service did not become healthy in expected duration")

            print(
                f"  Service in state {state}. Retrying ({tries} left) in 30 seconds..."
            )
            time.sleep(30)

    def _ecs_service_state(self) -> str:
        """
        Returns the rolloutState of the PRIMARY ECS service deployment. If
        the CiviForm service is not found or there is no PRIMARY deployment
        found, "NONE" is returned.

        An ECS service has many deployments. Each deployment has a status of
        PRIMARY, ACTIVE, or INACTIVE. There can only be one deployment with the
        PRIMARY status. A deployment with this status is the most recent
        deployment.

        Each deployment has a rolloutState of COMPLETED, FAILED, or IN_PROGRESS.
        The deployment becomes COMPLETED when all its containers pass their
        healthchecks.

        For CiviForm, the service usually only has one deployment. When we
        upgrade the CiviForm server version, the deployment for the old version
        goes to ACTIVE and a new PRIMARY deployment is created for the new
        version. Once the new PRIMARY deployment has a rolloutState of
        COMPLETED, the ACTIVE deployment stops its tasks and goes to the
        INACTIVE state.

        https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_Deployment.html.
        """
        res = self._call_cli(
            f"ecs describe-services --cluster={self._ecs_cluster} --services={self._ecs_service}"
        )

        services = res["services"]
        if services == None or len(services) != 1:
            return "NONE"

        for deployment in services[0]["deployments"]:
            if deployment["status"] == "PRIMARY":
                return deployment["rolloutState"]

        return "NONE"

    def _get_url_of_ecs_service(self) -> str:
        return f"https://{self.config.aws_region}.console.aws.amazon.com/ecs/v2/clusters/{self._ecs_cluster}/services/{self._ecs_service}/deployments"

    def get_load_balancer_dns(self, name: str) -> str:
        res = self._call_cli(f"elbv2 describe-load-balancers --names={name}")
        load_balancer = res["LoadBalancers"][0]
        return load_balancer["DNSName"]

    def get_url_of_secret(self, secret_name: str) -> str:
        return f"https://{self.config.aws_region}.console.aws.amazon.com/secretsmanager/secret?name={secret_name}"

    def get_url_of_s3_bucket(self, bucket_name: str) -> str:
        return f"https://{self.config.aws_region}.console.aws.amazon.com/s3/buckets/{bucket_name}"

    def _call_cli(self, command: str) -> Dict:
        command = f"aws --output=json --region={self.config.aws_region} " + command
        out = subprocess.check_output(shlex.split(command))
        return json.loads(out.decode("ascii"))
