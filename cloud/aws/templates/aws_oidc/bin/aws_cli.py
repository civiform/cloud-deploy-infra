import shlex
import subprocess
import json
import time
import inspect
import re
from typing import Dict, List

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
        self._call_cli(command, False)  # output = False

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

    # This is what the aws cli exits with when the resource you
    # are trying to operate on doesn't exist
    RESOURCE_NOT_FOUND_CODE = 254

    def s3_bucket_encryption(self, bucket_name: str) -> bool:
        result = self._call_cli(
            f's3api get-bucket-encryption --bucket "{bucket_name}"')
        try:
            key_arn = result['ServerSideEncryptionConfiguration']['Rules'][0][
                'ApplyServerSideEncryptionByDefault']['KMSMasterKeyID']
            key_match = re.match(
                r'.*key/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})',
                key_arn)
            if key_match:
                return key_match.groups()[0]
            else:
                raise ValueError(
                    f"KMSMasterKeyID in result from 'aws s3api get-bucket-encryption' did not have the expected format. Output: {result}"
                )
        except KeyError:
            # If the result does not contain the information we're looking for,
            # then encryption isn't enabled. This is probably okay, but since
            # we should be setting up encryption every time we are setting up
            # the backend, print a warning.
            print(
                f"WARNING: Could not find the encryption key used for the S3 bucket. It could be that this was not enabled from a failed setup run. Output of 'aws s3api get-bucket-encryption': {result}"
            )
            return None
        except subprocess.CalledProcessError as e:
            print(
                f'Error finding encryption state of the S3 bucket: {e.stdout.decode()}'
            )
            raise

    def resource_exists(self, resource_type: str, resource_name: str) -> bool:
        if resource_type == 'bucket':
            cmd = f's3api head-bucket --bucket "{resource_name}"'
            type_display_name = 'S3 bucket'
        elif resource_type == 'table':
            cmd = f'dynamodb describe-table --table-name "{resource_name}"'
            type_display_name = 'DynamoDB table'
        else:
            raise ValueError(
                f'{resource_type} is not a type recognized by the resource_exists function'
            )
        try:
            self._call_cli(cmd, False)
            return True
        except subprocess.CalledProcessError as e:
            if e.returncode == self.RESOURCE_NOT_FOUND_CODE:
                return False
            else:
                print(
                    f'Error detecting if the {type_display_name} exists: {e.stdout.decode()}'
                )
                raise

    def delete_bucket_files(self, bucket_name: str) -> bool:
        try:
            # Because we enable versioning, we have to delete all versions of
            # all objects, along with their delete markers.
            file_data = self._call_cli(
                f's3api list-object-versions --bucket {bucket_name} --output json --query "{{Objects: Versions[].{{Key:Key,VersionId:VersionId}}}}"'
            )
            if file_data['Objects']:
                file_data = str(file_data).replace('\'', '\\"')
                self._call_cli(
                    f's3api delete-objects --bucket {bucket_name} --delete "{file_data}"'
                )
            delete_markers = self._call_cli(
                f's3api list-object-versions --bucket {bucket_name} --output json --query "{{Objects: DeleteMarkers[].{{Key:Key,VersionId:VersionId}}}}"'
            )
            if delete_markers['Objects']:
                delete_markers = str(delete_markers).replace('\'', '\\"')
                self._call_cli(
                    f's3api delete-objects --bucket {bucket_name} --delete "{delete_markers}"'
                )
            return True
        except subprocess.CalledProcessError as e:
            print(
                f'Error attempting to delete all objects from the S3 bucket: {e.stdout.decode()}'
            )
            return False

    def delete_bucket_encryption_key(self, key_id: str):
        try:
            info = self._call_cli(f'kms describe-key --key-id {key_id}')
            if info['KeyMetadata']['KeyState'] == 'PendingDeletion':
                return True
            self._call_cli(
                f'kms schedule-key-deletion --key-id {key_id}', False)
            return True
        except subprocess.CalledProcessError as e:
            if e.returncode == self.RESOURCE_NOT_FOUND_CODE:
                # Key does not exist, so call it a success
                return True
            else:
                print(
                    f'Error deleting S3 bucket encryption key: {e.stdout.decode()}'
                )
                return False

    def delete_bucket_policy(self, bucket_name: str) -> bool:
        try:
            self._call_cli(
                f's3api delete-bucket-policy --bucket "{bucket_name}"', False)
            return True
        except subprocess.CalledProcessError as e:
            print(f'Error deleting S3 bucket policy: {e.stdout.decode()}')
            return False

    def delete_bucket(self, bucket_name: str) -> bool:
        try:
            self._call_cli(
                f's3api delete-bucket --bucket "{bucket_name}"', False)
            return True
        except subprocess.CalledProcessError as e:
            if e.returncode == self.RESOURCE_NOT_FOUND_CODE:
                # Bucket does not exist, so call it a success
                return True
            else:
                print(f'Error deleting bucket: {e.stdout.decode()}')
                return False

    def delete_table(self, table_name: str) -> bool:
        try:
            self._call_cli(
                f'dynamodb delete-table --table-name "{table_name}"', False)
            return True
        except subprocess.CalledProcessError as e:
            if e.returncode == self.RESOURCE_NOT_FOUND_CODE:
                # Table does not exist, so call it a success
                return True
            else:
                print(f'Error deleting DynamoDB table: {e.stdout.decode()}')
                return False

    def list_tasks(self, cluster: str, service_name: str) -> List[str]:
        res = self._call_cli(f"ecs list-tasks --cluster {cluster} --service-name {service_name}")
        # TODO: make this a list of strings if it isn't
        return res["taskArns"]

    def execute_command(self, cluster: str, task: str, container: str, interactive: bool = True, command: str = '/bin/sh') -> bool:
        if interactive:
            interact_mode = "--interactive"
        else:
            interact_mode = "--non-interactive"

        #TODO: try: and except some error?
        self._call_cli(f"ecs execute-command --cluster {cluster} --task {task} --container {container} {interact_mode} --command '{command}'")
        return True

    def list_db_endpoints(self) -> List[str]:
        res = self._call_cli("rds describe-db-instances")
        db_endpoints = []
        for db_instances in res:
            db_endpoints.append(f"{db_instances['Endpoint']['Address']}:{db_instances['Endpoint']['Port']}")
        # TODO: make this a list of strings if it isn't
        return db_endpoints

    def _call_cli(self, command: str, output: bool = True) -> Dict:
        base = f"aws --region={self.config.aws_region} "
        if output:
            base += "--output=json "
        command = base + command
        out = subprocess.check_output(
            shlex.split(command), stderr=subprocess.STDOUT)
        if output:
            return json.loads(out.decode("ascii"))
        return
