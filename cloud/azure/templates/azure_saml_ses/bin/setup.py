#! /usr/bin/env python3

import subprocess
import tempfile
from typing import Dict

from cloud.shared.bin.lib import terraform
from cloud.shared.bin.lib.print import print
from cloud.shared.bin.lib.setup_template import SetupTemplate
from cloud.shared.bin.lib.config_loader import ConfigLoader


class Setup(SetupTemplate):
    """
    Template Setup

    This script handles the setup for the specific template. Calls out
    to many different shell script in order to setup the environment
    outside of the terraform setup. The setup is in two phases: pre_terraform_setup
    and post_terraform_setup.
    """

    resource_group = None
    key_vault_name = None
    log_file_path = None

    def requires_post_terraform_setup(self):
        return True

    def detect_backend_state_resources(self):
        # Not yet implemented, so assume
        # none of the resources exist yet.
        return {'bucket': None, 'table': None}

    def destroy_backend_resources(self, resources: Dict):
        # Not yet implemented
        return

    def pre_terraform_setup(self):
        print(" - Setting up the keyvault")
        self._setup_keyvault()
        print(" - Setting up the SAML keystore")
        self._setup_saml_keystore()
        print(" - Finish Pre-Terraform setup.")
        return True

    def get_current_user(self):
        current_user_process = subprocess.run(
            [
                "/bin/bash", "-c",
                f"source cloud/azure/bin/lib.sh && azure::get_current_user_id"
            ],
            capture_output=True)
        current_user = current_user_process.stdout.decode("ascii")
        if not current_user:
            raise RuntimeError("Could not find the logged in user")
        return current_user

    def setup_log_file(self):
        self._setup_resource_group()
        _, self.log_file_path = tempfile.mkstemp()
        subprocess.run(
            ["cloud/azure/bin/init-azure-log", self.log_file_path], check=True)

    def post_terraform_setup(self):
        self._get_adfs_user_inputs()
        self._configure_slot_settings()
        # Run terraform again as get_adfs_user_inputs updated secret variables.
        terraform.perform_apply(self.config)

    def cleanup(self):
        self._upload_log_file()
        subprocess.run(
            ["/bin/bash", "-c", "rm -f $HOME/.ssh/bastion*"], check=True)

    def _configure_slot_settings(self):
        subprocess.run(["cloud/azure/bin/configure-slot-settings"], check=True)

    def _upload_log_file(self):
        subprocess.run(
            ["cloud/azure/bin/upload-log-file", self.log_file_path], check=True)

    def _get_adfs_user_inputs(self):
        print(
            ">>>> You will need to navigate to https://portal.azure.com/ and " +
            "select the app_service that was created. Select authentication" +
            ", and add a new Microsoft identity provider. Select 'Allow " +
            "unauthenticated access'. Get the App (client) id.")
        self._input_to_keystore("adfs-client-id")

        print(
            ">>>> Navigate to the newly created authentication" +
            " provider and click the endpoints button from the overview and" +
            " find the OpenID uri (ends with /openid-configuration).")
        self._input_to_keystore("adfs-discovery-uri")

        print(
            ">>>> In the same view (authentication provider page), navigate " +
            " to certificates & secrets page, and add a new client secret. " +
            "Copy the value.")
        self._input_to_keystore("adfs-secret")

    def _input_to_keystore(self, secret_id):
        key_vault_name = self.config.get_config_var("KEY_VAULT_NAME")
        subprocess.run(
            [
                "cloud/azure/bin/input-secrets-to-keystore", "-k",
                key_vault_name, "-s", secret_id
            ],
            check=True)

    def _setup_resource_group(self):
        resource_group = self.config.get_config_var("AZURE_RESOURCE_GROUP")
        resource_group_location = self.config.get_config_var("AZURE_LOCATION")
        subprocess.run(
            [
                "cloud/azure/bin/create_resource_group", "-g", resource_group,
                "-l", resource_group_location
            ],
            check=True)
        self.resource_group = resource_group
        self.resource_group_location = resource_group_location

    def _setup_keyvault(self):
        if not self.resource_group:
            raise RuntimeError("Resource group required")
        key_vault_name = self.config.get_config_var("KEY_VAULT_NAME")
        subprocess.run(
            [
                "cloud/azure/bin/setup-keyvault", "-g", self.resource_group,
                "-v", key_vault_name, "-l", self.resource_group_location
            ],
            check=True)
        self.key_vault_name = key_vault_name

    def _setup_saml_keystore(self):
        if not self.resource_group:
            raise RuntimeError("Resource group required")
        if not self.key_vault_name:
            raise RuntimeError("Key Vault Name Required")

        saml_keystore_storage_account = self.config.get_config_var(
            "SAML_KEYSTORE_ACCOUNT_NAME")
        subprocess.run(
            [
                "cloud/azure/bin/setup-saml-keystore", "-g",
                self.resource_group, "-v", self.key_vault_name, "-l",
                self.resource_group_location, "-s",
                saml_keystore_storage_account
            ],
            check=True)
