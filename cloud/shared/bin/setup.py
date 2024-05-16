import os
import subprocess
import sys
import inspect
from typing import List

from cloud.shared.bin.lib.config_loader import ConfigLoader
from cloud.shared.bin.lib.setup_class_loader import get_config_specific_setup
from cloud.shared.bin.lib.print import print
from cloud.shared.bin.lib import terraform
from cloud.shared.bin import destroy
from cloud.shared.bin.lib.color import Color
"""
Setup.py sets up and runs the initial terraform deployment. It's broken into
2 parts:
1) Run Setup scripts
2) Terraform Init/Plan/Apply

The script generates a .tfvars file that is used to deploy via terraform.
"""


def run(config: ConfigLoader, params: List[str]):
    ###############################################################################
    # Load Setup Class for the specific template directory
    ###############################################################################

    if os.getenv('SKIP_USER_INPUT'):
        print(
            'Proceeding automatically since the "SKIP_USER_INPUT" environment variable was set.'
        )
    else:
        msg = inspect.cleandoc(
            """
            ###########################################################################
                                            WARNING                                                       
            ###########################################################################
            You are getting ready to run the setup script which will create the necessary 
            infrastructure for CiviForm. Interrupting the script in the middle may leave 
            your infrastructure in an inconsistent state and require you to manually 
            clean up resources in your cloud provider's console.
            
            Before continuing, be sure you have at least 20 minutes free to allow the 
            script to complete. If your initial setup failed and you are re-running 
            this script, leave at least 30 minutes to allow time for resources to be 
            destroyed and recreated.

            Would you like to continue with the setup? [y/N] > 
            """)
        answer = input(msg)
        if answer not in ['y', 'Y', 'yes']:
            exit(1)
    secret_length = config.get_config_var("RANDOM_PASSWORD_LENGTH")
    if not secret_length:
        print(
            f'{Color.RED}RANDOM_PASSWORD_LENGTH is not set in the config file. Please add {Color.CYAN}export RANDOM_PASSWORD_LENGTH=64{Color.RED} to your config file and rerun this script.{Color.END}'
        )
        exit(1)

    if int(secret_length) < 32:
        print(
            f'{Color.RED}RANDOM_PASSWORD_LENGTH is currently set to {secret_length}, but it must be 32 or greater. Please add {Color.CYAN}export RANDOM_PASSWORD_LENGTH=64{Color.RED} to your config file and rerun this script.{Color.END}'
        )
        exit(1)

    template_setup = get_config_specific_setup(config)

    template_setup.setup_log_file()
    current_user = template_setup.get_current_user()

    image_tag = config.get_config_var("IMAGE_TAG")
    log_args = f"\"{image_tag}\" {current_user}"

    try:
        resources = template_setup.detect_backend_state_resources()
        if resources['bucket'] or resources['table']:
            msg = inspect.cleandoc(
                """
                ###########################################################################
                                                WARNING                                                       
                ###########################################################################
                Backend resources already exist. This may be due to a previous deployment.
                Proceeding with the setup will destroy these resources and recreate them. 
                THIS IS A DESTRUCTIVE CHANGE and may cause a loss of data if the resources 
                are in use by another deployment. You should verify that no other deployments 
                are using these resources before proceeding.

                Would you like to destroy the backend resources and recreate them? [y/N] >
                """)
            answer = input(msg)
            if answer in ['y', 'Y', 'yes']:
                destroy.run(config, [])
                if not template_setup.destroy_backend_resources(resources):
                    msg = inspect.cleandoc(
                        """
                        One or more errors occurred when attempting to delete Terraform backend state resources.
                        You can try destroying the backend state resources again by exiting this script
                        and running `bin/run destroy_backend_state_resources`. If the script continues to fail,
                        you may need to manually delete the resources in your cloud provider's console.
                        
                        Would you like to continue anyway? [y/N] >
                        """)
                    answer = input(msg)
                    if answer not in ['y', 'Y', 'yes']:
                        exit(1)
            else:
                exit(1)

        print("Starting pre-terraform setup")
        if not template_setup.pre_terraform_setup():
            raise Exception("Setting up terraform backend resources failed")

        ###############################################################################
        # Terraform Init/Plan/Apply
        ###############################################################################
        print("Starting terraform deploy")
        deploy_succeeded = terraform.perform_apply(config)
        if not deploy_succeeded:
            raise Exception("Terraform apply failed")

        ###############################################################################
        # Post Run Setup Tasks (if needed)
        ###############################################################################
        if template_setup.requires_post_terraform_setup():
            print("Starting post-terraform setup")
            template_setup.post_terraform_setup()

        subprocess.run(
            [
                "/bin/bash", "-c",
                f"source cloud/shared/bin/lib.sh && LOG_TEMPFILE={template_setup.log_file_path} log::deploy_succeeded {log_args}"
            ],
            check=True)
    except BaseException as err:
        subprocess.run(
            [
                "/bin/bash", "-c",
                f"source cloud/shared/bin/lib.sh && LOG_TEMPFILE={template_setup.log_file_path} log::deploy_failed {log_args}"
            ],
            check=True)
        print(
            "\nDeployment Failed. Check Troubleshooting page for known issues:\n"
            +
            "https://docs.civiform.us/it-manual/sre-playbook/terraform-deploy-system#troubleshooting\n",
        )
        # rethrow error so that full stack trace is printed
        raise err

    finally:
        template_setup.cleanup()
