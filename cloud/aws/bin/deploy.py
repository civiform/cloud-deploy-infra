import textwrap
import os

from cloud.aws.templates.aws_oidc.bin import resources
from cloud.aws.templates.aws_oidc.bin.aws_cli import AwsCli
from cloud.shared.bin.lib import terraform
from cloud.shared.bin.lib.print import print
from cloud.shared.bin.lib.color import Color
from cloud.shared.bin.lib.config_loader import ConfigLoader


def run(config: ConfigLoader):
    aws = AwsCli(config)

    if not config.is_test():
        _check_application_secret_length(config, aws)
        _check_for_postgres_upgrade(config, aws)

    if not terraform.perform_apply(config):
        print('Terraform deployment failed.')
        # TODO(#2606): write and upload logs.
        raise ValueError('Terraform deployment failed.')

    if config.is_test():
        print('Test completed')
        return

    aws.wait_for_ecs_service_healthy()
    lb_dns = aws.get_load_balancer_dns(f'{config.app_prefix}-civiform-lb')
    base_url = config.get_base_url()
    print(
        f'Server is available at {lb_dns}. Check your domain registrar to ensure your CNAME record for {base_url} points to this address.'
    )


def _check_application_secret_length(config: ConfigLoader, aws: AwsCli):
    if not config.is_test():
        secret_length = aws.get_application_secret_length()
        if secret_length < 32:
            print(
                f'{Color.RED}The application secret must be at least 32 characters in length, and ideally 64 characters. The current secret has a length of {secret_length}. See https://docs.civiform.us/it-manual/sre-playbook/initial-deployment/terraform-deploy-system#rotating-the-application-secret for details on how to regenerate the secret with a longer length.{Color.END}'
            )
            exit(1)


def _check_for_postgres_upgrade(config: ConfigLoader, aws: AwsCli):
    # https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_UpgradeDBInstance.PostgreSQL.html
    # For each major PG version, the oldest allowed PG minor you must be on in order to upgrade to that major version.
    # We don't really care which minor version of the upgraded version you get upgraded to, as AWS will take care of upgrading
    # the minor version later (e.g. 12.17 can only upgrade to 16.1, but then AWS will upgrade that again to 16.2
    # automatically once it's at 16.1 in the next maintenance window).
    #
    # We are currently only upgrading 12 -> 16. Fill in this table as needed for future upgrades.
    #
    # major_version_to_upgrade_to: {current_major_version: oldest_allowable_minor_version}
    pg_upgrade_table = {16: {12: 17}}
    postgresql_major_to_apply = config.get_config_var(
        "POSTGRESQL_MAJOR_VERSION") or terraform.find_variable_default(
            config, 'postgresql_major_version')
    if postgresql_major_to_apply:
        to_apply = int(postgresql_major_to_apply)
        current_major, current_minor = aws.get_postgresql_version(
            f'{config.app_prefix}-{resources.DATABASE}')
        if to_apply != current_major:
            print(
                textwrap.dedent(
                    f'''
                {Color.CYAN}This version of CiviForm contains an upgrade to PostgreSQL {to_apply}. Your install is currently using PostgreSQL version {current_major}.{current_minor}.
                
                The upgrade may take an extra 10-20 minutes to complete, during which time the CiviForm application will be unavailable. Before upgrading, ensure you have a backup of your database. You can do this by running bin/run and choosing the dumpdb command.
                Additionally, a snapshot will be performed just prior to the upgrade. The snapshot will have a name that starts with "preupgrade". You may also have a snapshot called "{config.app_prefix}-civiform-db-finalsnapshot".
                {Color.END}
                '''))
            if to_apply < current_major:
                raise ValueError(
                    f'{Color.RED}Your current version of PostgreSQL appears to be newer than the version specified for this CiviForm release. Ensure you are using the correct version of the cloud-deploy-infra repo and POSTGRESQL_MAJOR_VERSION is unset or set appropriately.{Color.END}'
                )
            if to_apply not in pg_upgrade_table:
                raise ValueError(
                    f'{Color.RED}Unsupported upgrade to PostgreSQL version {to_apply} specified for POSTGRESQL_MAJOR_VERSION. If this seems incorrect, contact a CiviForm maintainer.{Color.END}'
                )
            if current_major not in pg_upgrade_table[to_apply]:
                print(
                    f'{Color.YELLOW}This version of the deployment tool does not have information about if {current_major}.{current_minor} is sufficiently new enough to upgrade to version {to_apply}. Check https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_UpgradeDBInstance.PostgreSQL.html and verify this is a valid upgrade path.{Color.END}'
                )
                if os.getenv('SKIP_USER_INPUT'):
                    print('Proceeding since SKIP_USER_INPUT is set.')
                else:
                    answer = input(
                        f'{Color.YELLOW}Would you like to proceed with the upgrade? (y/N): {Color.END}'
                    )
                    if answer.lower() not in ['y', 'yes']:
                        exit(1)
            elif current_minor < pg_upgrade_table[to_apply][current_major]:
                print(
                    f'{Color.RED}In order to upgrade to version {to_apply}, you must first upgrade to at least PostgreSQL {current_major}.{pg_upgrade_table[to_apply][current_major]}. You will need to perform this upgrade in the AWS RDS console before proceeding.{Color.END}'
                )
                exit(1)
            # If a user sets ALLOW_POSTGRESQL_UPGRADE in their config file, config.get_config_var will pick it up.
            # If they've set it as an environment variable, we need to detect that and then add it to the config
            # object ourselves so that it is picked up with the manifest is compiled.
            if config.get_config_var("ALLOW_POSTGRESQL_UPGRADE") != "true":
                if os.getenv('SKIP_USER_INPUT'):
                    print('Proceeding since SKIP_USER_INPUT is set.')
                else:
                    answer = input(
                        f'{Color.YELLOW}Would you like to proceed with the upgrade? (y/N): {Color.END}'
                    )
                    if answer.lower() not in ['y', 'yes']:
                        exit(2)
                config.add_config_value("ALLOW_POSTGRESQL_UPGRADE", "true")
