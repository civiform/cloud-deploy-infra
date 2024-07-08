import secrets
from getpass import getpass
from typing import Dict

from cloud.aws.templates.aws_oidc.bin.aws_cli import AwsCli
from cloud.aws.templates.aws_oidc.bin import resources
from cloud.aws.templates.aws_oidc.bin.aws_template import AwsSetupTemplate
from cloud.shared.bin.lib.config_loader import ConfigLoader
from cloud.shared.bin.lib.print import print

SECRETS: Dict[str, str] = {
    resources.ADFS_CLIENT_ID:
        'Client id for the ADFS configuration. Enter any value if you do not use ADFS.',
    resources.ADFS_SECRET:
        'Secret for the ADFS configuration. Enter any value if you do not use ADFS.',
    resources.APPLICANT_OIDC_CLIENT_ID:
        'Client ID for your OIDC provider for applicants. Enter any value if not applicable.',
    resources.APPLICANT_OIDC_CLIENT_SECRET:
        'Client secret for your OIDC provider for applicants. Enter any value if not applicable.',
    resources.ADMIN_OIDC_CLIENT_ID:
        'Client ID for your OIDC provider for admins. Enter any value if not applicable.',
    resources.ADMIN_OIDC_CLIENT_SECRET:
        'Client secret for your OIDC provider for admins. Enter any value if not applicable.',
    resources.ESRI_ARCGIS_API_TOKEN_SECRET:
        'Client secret for your Esri ArcGis Online api token. Enter any value if not applicable.',
}


class Setup(AwsSetupTemplate):

    def __init__(self, config: ConfigLoader):
        super().__init__(config)
        self._aws_cli = AwsCli(config)

    def get_current_user(self) -> str:
        current_user = self._aws_cli.get_current_user()
        if not current_user:
            raise RuntimeError('Could not find the logged in user')
        return current_user

    def detect_backend_state_resources(self) -> Dict:
        """
        Detects if the S3 bucket and DynamoDB table exist that are set up
        to store the Terraform backend. Returns a dict with two top-level
        keys of 'bucket' and 'table'. If either of these don't exist, they
        will have values of None. Otherwise, they will contain data needed
        to destroy the resource.
        """
        print(' - Checking for existing backend state resources')
        result = {'bucket': None, 'table': None}
        bucket_name = f'{self.config.app_prefix}-{resources.S3_TERRAFORM_STATE_BUCKET}'
        bucket_exists = self._aws_cli.resource_exists('bucket', bucket_name)
        if bucket_exists:
            result['bucket'] = {'name': bucket_name}
            key_id = self._aws_cli.s3_bucket_encryption(bucket_name)
            result['bucket']['encryption_key'] = key_id
        table_name = f'{self.config.app_prefix}-{resources.S3_TERRAFORM_LOCK_TABLE}'
        if self._aws_cli.resource_exists('table', table_name):
            result['table'] = {'name': table_name}
        return result

    def destroy_backend_resources(self, resources: Dict):
        """
        Destroys AWS resources used for storting the Terraform state.
        Takes a dictionary that is the output of detect_backend_state_resources.
        Attempts to delete all resources, even if one of the deletions fails.
        Since we're in a can't-turn-back kind of state once we delete one of
        these resources, we delete as much as we can so there's less for the user
        to clean up if something fails.
        """
        success = True
        if resources['bucket']:
            bucket_name = resources['bucket']['name']
            success = self._aws_cli.delete_bucket_files(bucket_name) and success
            if 'encryption_key' in resources['bucket'].keys():
                success = self._aws_cli.delete_bucket_encryption_key(
                    resources['bucket']['encryption_key']) and success
            success = self._aws_cli.delete_bucket_policy(
                bucket_name) and success
            success = self._aws_cli.delete_bucket(bucket_name) and success
        if resources['table']:
            success = self._aws_cli.delete_table(
                resources['table']['name']) and success
        return success

    def pre_terraform_setup(self):
        print(' - Running the setup script in terraform')
        return self._tf_run_for_aws(is_destroy=False)

    def requires_post_terraform_setup(self):
        return True

    def post_terraform_setup(self):
        if self.config.is_test():
            print(" - Test. Skipping post terraform setup.")
            return

        for name, doc in SECRETS.items():
            self._maybe_set_secret_value(
                f'{self.config.app_prefix}-{name}', doc)
        self._maybe_change_default_db_password()
        self._aws_cli.wait_for_ecs_service_healthy()
        self._print_final_message()

    def _maybe_set_secret_value(self, secret_name: str, documentation: str):
        """
        Some secrets like login integration credentials created empty in
        terraform. The values need to be provided by users. This method runs
        after terraform created empty secrets and it asks user to provide
        actual secret values. Without these values server will not start so
        it has be run immediately after the initial setup is done.
        """
        print('')
        url = self._aws_cli.get_url_of_secret(secret_name)
        if self._aws_cli.is_secret_empty(secret_name):
            print(
                f'Secret {secret_name} is not set. It needs to be set to a non-empty value.'
            )
            print(documentation)
            print(f'You can later change the value in AWS console: {url}')
            new_value = getpass('enter value -> ').strip()
            while new_value.strip() == '':
                print('Value cannot be empty.')
                new_value = getpass('enter value -> ').strip()
            self._aws_cli.set_secret_value(secret_name, new_value)
            print('Secret value successfully set.')
        else:
            print(f'Secret {secret_name} already has a value set.')
            print(f'You can check and update it in AWS console: {url}')

    def _maybe_change_default_db_password(self):
        """
        Terraform creates database password secret with a random value and
        creates database and ECS service that use that password. The problem
        is that because password generated within terraform - its value is
        stored in the Terraform state. To avoid exposing password in the state
        this method regenerates password and updates database and server to use
        the new password.
        """
        print()
        print('Checking database password...')
        app_prefix = self.config.app_prefix
        secret_name = f'{app_prefix}-{resources.POSTGRES_PASSWORD}'
        if self._aws_cli.is_db_password_default(secret_name):
            new_password = secrets.token_urlsafe(40)
            print(
                'Default database password is used. Generating new password ' +
                'and updating deployment.')
            self._aws_cli.update_master_password_in_database(
                f'{app_prefix}-{resources.DATABASE}', new_password)
            print('Database password has been changed.')
            self._aws_cli.set_secret_value(secret_name, new_password)
            self._aws_cli.restart_ecs_service()
            print(f'ECS service has been restarted to pickup the new password.')
        else:
            print('Password has already been changed. Not touching it.')
        print(
            f'You can see the password here: {self._aws_cli.get_url_of_secret(secret_name)}'
        )

    def _print_final_message(self):
        app = self.config.app_prefix

        # Print info about load balancer url.
        print()
        lb_dns = self._aws_cli.get_load_balancer_dns(
            f'{app}-{resources.LOAD_BALANCER}')
        print(f'Server is available on url: {lb_dns}')
        print('\nNext steps to complete your Civiform setup:')
        base_url = self.config.get_base_url()
        print(
            f'In your domain registrar create a CNAME record for {base_url} to point to {lb_dns}.'
        )
        ses_address = self.config.get_config_var('SENDER_EMAIL_ADDRESS')
        print(
            f'Verify email address {ses_address}. If you didn\'t receive the ' +
            'confirmation email, check that your SES is not in sandbox mode.')
