import textwrap
import os

from cloud.aws.templates.aws_oidc.bin import resources
from cloud.aws.templates.aws_oidc.bin.aws_cli import AwsCli
from cloud.shared.bin.lib import terraform
from cloud.shared.bin.lib.print import print
from cloud.shared.bin.lib.color import red, yellow, cyan
from cloud.shared.bin.lib.config_loader import ConfigLoader


def run(config: ConfigLoader):
    aws = AwsCli(config)

    if not config.is_test():
        _check_application_secret_length(config, aws)
        _check_for_postgres_upgrade(config, aws)

    if config.get_config_var('POSTGRES_RESTORE_SNAPSHOT_IDENTIFIER'):
        answer = input(
            yellow(
                """
            ###########################################################################
                                            WARNING                                                       
            ###########################################################################
            You are attempting to deploy with POSTGRES_RESTORE_SNAPSHOT_IDENTIFIER set 
            which will restore your database to a former snapshot and can result in data 
            loss. We recommend taking a manual snapshot of the database before running 
            this command.
            
            Do you wish to proceed? [y/N] > 
            """))
        if answer.lower() not in ['y', 'yes']:
            exit(1)
    if not terraform.perform_apply(config):
        print('Terraform deployment failed.')
        # TODO(#2606): write and upload logs.
        raise ValueError('Terraform deployment failed.')

    if config.is_test():
        print('Test completed')
        return

    # If we've restored from a snapshot, the database will have a password
    # from the Terraform manifest that doesn't match the password stored in
    # the secret.
    if config.get_config_var('POSTGRES_RESTORE_SNAPSHOT_IDENTIFIER'):
        print(
            'Setting database password from secret after restoring from a snapshot.'
        )
        aws.sync_database_password_with_secret(config)

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
                red(
                    f'The application secret must be at least 32 characters in length, and ideally 64 characters. The current secret has a length of {secret_length}. See https://docs.civiform.us/it-manual/sre-playbook/initial-deployment/terraform-deploy-system#rotating-the-application-secret for details on how to regenerate the secret with a longer length.'
                ))
            exit(1)


def _check_for_postgres_upgrade(config: ConfigLoader, aws: AwsCli):
    # https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_UpgradeDBInstance.PostgreSQL.html
    #
    # Because RDS won't automatically choose the appopriate minor version to upgrade to based on your current version,
    # we have to specifically specify the valid 16.x minor upgrade path. Unfortunately, we'll have to keep the
    # upgrade_path dictionary up to date as new minor versions of 12.x are released.
    #
    # When we aren't upgrading the major version, we want to make sure POSTGRESQL_VERSION stays simply "16" so that Terraform
    # doesn't try applying a downgrade to 16.1 if we're on 16.2 or later.
    #
    # If a user specifies a 16.x specifically in POSTGRESQL_VERSION, we'll pass that through directly since we assume the user
    # knows what they are trying to do.

    upgrade_path = {
        '12.17': '16.1',
        '12.18': '16.2',
        '12.19': '16.3',
    }

    specified_version = config.get_config_var('POSTGRESQL_VERSION') or \
                        terraform.find_variable_default(config, 'postgresql_version')
    if specified_version:
        major_to_apply, minor_to_apply = (
            specified_version.split('.') + [None])[:2]
        major_to_apply = int(major_to_apply)
        current_major, current_minor = aws.get_postgresql_version(
            f'{config.app_prefix}-{resources.DATABASE}')
        current_version = f'{current_major}.{current_minor}'
        if major_to_apply != current_major:
            print(
                textwrap.dedent(
                    cyan(
                        f'''
                This version of CiviForm contains an upgrade to PostgreSQL {major_to_apply}. Your install is currently using PostgreSQL version {current_version}.
                
                The upgrade may take an extra 10-20 minutes to complete, during which time the CiviForm application will be unavailable. Before upgrading, ensure you have a backup of your database. You can do this by running bin/run and choosing the dumpdb command.
                
                Additionally, a snapshot will be performed just prior to the upgrade. The snapshot will have a name that starts with "preupgrade". You may also have a snapshot called "{config.app_prefix}-civiform-db-finalsnapshot".
                ''')))
            if major_to_apply < current_major:
                print(
                    red(
                        'Your current version of PostgreSQL appears to be newer than the version specified for this CiviForm release. Ensure you are using the correct version of the cloud-deploy-infra repo and POSTGRESQL_VERSION is unset or set appropriately.'
                    ))
                exit(1)
            if major_to_apply != 16:
                print(
                    red(
                        f'Unsupported upgrade to PostgreSQL version {major_to_apply} specified for POSTGRESQL_VERSION. If this seems incorrect, contact a CiviForm maintainer.'
                    ))
                exit(1)
            if current_major == 12 and current_minor < 17:
                print(
                    red(
                        f'In order to upgrade to PostgreSQL {major_to_apply}, you must first upgrade to PostgreSQL 12.17 or a later PostgreSQL 12 minor version. You will need to perform this upgrade in the AWS RDS console before proceeding.'
                    ))
                exit(1)
            if current_version not in upgrade_path.keys():
                print(
                    yellow(
                        f'This version of the CiviForm deployment tool has no information about your current PostgreSQL version of {current_version} and thus cannot choose the correct version to upgrade to. If you proceed, we will attempt to upgrade to the latest {major_to_apply}.x version, but this may not succeed. Check https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_UpgradeDBInstance.PostgreSQL.html to verify that this is a valid upgrade path.'
                    ))
                if os.getenv('SKIP_USER_INPUT'):
                    print('Proceeding since SKIP_USER_INPUT is set.')
                else:
                    answer = input(
                        yellow(
                            'Would you like to proceed with the upgrade? (y/N): '
                        ))
                    if answer.lower() not in ['y', 'yes']:
                        exit(1)
            else:
                if minor_to_apply is None:
                    config.add_config_value(
                        'POSTGRESQL_VERSION', upgrade_path[current_version])

            # If a user sets ALLOW_POSTGRESQL_UPGRADE in their config file, config.get_config_var will pick it up.
            # If they've set it as an environment variable, we need to detect that and then add it to the config
            # object ourselves so that it is picked up with the manifest is compiled.
            if config.get_config_var('ALLOW_POSTGRESQL_UPGRADE') != 'true':
                if os.getenv('SKIP_USER_INPUT'):
                    print(
                        'Proceeding with upgrade since SKIP_USER_INPUT is set.')
                else:
                    answer = input(
                        yellow(
                            'Would you like to proceed with the upgrade? (y/N): '
                        ))
                    if answer.lower() not in ['y', 'yes']:
                        exit(2)
                config.add_config_value('ALLOW_POSTGRESQL_UPGRADE', 'true')

            # We must force APPLY_DATABASE_CHANGES_IMMEDIATELY to true, since we are changing the database parameters along
            # with the database itself, and we need to apply both changes at the same time. We can't wait for the next
            # maintenance window.
            config.add_config_value(
                'APPLY_DATABASE_CHANGES_IMMEDIATELY', 'true')

            print(
                cyan(
                    f'Proceeding with upgrade to PostgreSQL {config.get_config_var("POSTGRESQL_VERSION")}.'
                ))
