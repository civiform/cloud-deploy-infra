import shlex
import subprocess
import json
import time
import inspect
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
        have rolloutStatus of COMPLETED. If the PRIMARY deployment ID ends up
        being different than the ID we attempting to deploy, then the deployment
        failed and we've rolled back.

        Gives up after 60 tries, sleeps 30 seconds between each try.
        """
        print(
            "\nWaiting for CiviForm ECS service to become healthy.\n"
            f"Service URL: {self._get_url_of_ecs_service()}")

        error_text = inspect.cleandoc(
            """
            go to the Service URL printed above and click on the logs tab.
            More details at https://docs.civiform.us/it-manual/sre-playbook/terraform-deploy-system/terraform-aws-deployment#inspecting-logs
            For debugging help, contact the CiviForm oncall: https://docs.civiform.us/governance-and-management/project-management/on-call-guide#on-call-responsibilities
            """)

        current_deployment_id = None
        tries = 60
        while True:
            info = self._ecs_service_state()
            id = info["id"]
            state = info["state"]
            current_deployment_id = id if current_deployment_id is None else current_deployment_id

            if state == "COMPLETED":
                if id != current_deployment_id:
                    print(
                        "ERROR: The deployment that is now COMPLETED has a different ID than the one we were waiting for.\n"
                        "This probably means the new tasks are crash-looping and we've rolled back to the previous deployment.\n"
                        "To view the logs to see what happened, " + error_text)
                    raise Exception("Deployment completed with different ID")
                print("Service is healthy.")
                return

            if state == "FAILED":
                print(
                    "ERROR: Service deployment has failed. This usually means the new tasks are crash-looping.\n"
                    "To view the logs to see what happened, " + error_text)
                raise Exception("Service failed")

            tries -= 1
            if tries == 0:
                print(
                    "ERROR: service did not become healthy in expected amount of time.\n"
                    "This usually means the new tasks are crash-looping, but can mean the check timed out before the service finished starting.\n"
                    "To check the health of the service, " + error_text)
                raise Exception(
                    "Service did not become healthy in expected duration")

            print(
                f"  Service in state {state}. Retrying ({tries} left) in 30 seconds..."
            )
            time.sleep(30)

    def set_lock_table_digest_value(self, value):
        """
        Sets the lock file digest value in DynamoDB to the given value. This
        digest value is a checksum of the Terraform state file stored in S3.

        If something goes wrong during deployment, especially when a user has
        force-unlocked due to a previous issue and then multiple apply actions
        are happening at once, the digest value for the Terraform lock file in
        S3 can be incorrect. This function lets us set the digest value to
        the correct value, as given by the error message of a previous
        Terraform command, without having to go into the AWS console to
        set it manually.
        """
        table = f'{self.config.app_prefix}-{resources.S3_TERRAFORM_LOCK_TABLE}'
        file = f'{self.config.app_prefix}-{resources.S3_TERRAFORM_STATE_BUCKET}'
        command = f'dynamodb put-item --table-name={table} --item=\'{{"LockID":{{"S":"{file}/tfstate/terraform.tfstate-md5"}},"Digest":{{"S":"{value}"}}}}\''
        self._call_cli(command, False)

    def _ecs_service_state(self) -> Dict:
        """
        Returns the ID and rolloutState of the PRIMARY ECS service deployment. If
        the CiviForm service is not found or there is no PRIMARY deployment
        found, an empty dictionary is returned.

        An ECS service has many deployments. Each deployment has a status of
        PRIMARY, ACTIVE, or INACTIVE. There can only be one deployment with the
        PRIMARY status.

        Each deployment has a rolloutState of COMPLETED, FAILED, or IN_PROGRESS.
        The deployment becomes COMPLETED when all its containers pass their
        healthchecks.

        For CiviForm, the service usually only has one deployment. When we
        upgrade the CiviForm server version, the deployment for the old version
        goes to ACTIVE and a new PRIMARY deployment is created for the new
        version. Once the new PRIMARY deployment has a rolloutState of
        COMPLETED, the ACTIVE deployment stops its tasks and goes to the
        INACTIVE state.

        Because we have the deployment circuit breaker enabled, if a deployment
        fails, it will roll back to the last successful deployment and mark it
        as PRIMARY again. This is why we also provide the ID in this function, so
        that we can detect if the new deployment was successful, or if we've
        rolled back.

        https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_Deployment.html.
        """
        res = self._call_cli(
            f"ecs describe-services --cluster={self._ecs_cluster} --services={self._ecs_service}"
        )

        services = res["services"]
        if services == None or len(services) != 1:
            return {}

        for deployment in services[0]["deployments"]:
            if deployment["status"] == "PRIMARY":
                return {
                    "id": deployment["id"],
                    "state": deployment["rolloutState"]
                }

        return {}

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

    def _call_cli(self, command: str, output: bool = True) -> Dict:
        base = f"aws --region={self.config.aws_region} "
        if output:
            base += "--output=json "
        command = base + command
        out = subprocess.check_output(shlex.split(command))
        if output:
            return json.loads(out.decode("ascii"))
        return
