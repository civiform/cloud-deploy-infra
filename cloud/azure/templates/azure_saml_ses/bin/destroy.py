#! /usr/bin/env python3

import os
import subprocess

from cloud.shared.bin.lib.print import print
from cloud.shared.bin.lib.setup_template import SetupTemplate


class Destroy(SetupTemplate):
    """
    Destroy the setup
    """

    def post_terraform_destroy(self):
        print(" - Purge the keyvault")
        self._purge_keyvault()
        print(" - Deleting AWS Access Key")
        self._delete_aws_access_key()

    def _delete_aws_access_key(self):
        access_key_id = os.getenv("AWS_ACCESS_KEY_ID")
        if access_key_id:
            subprocess.run(
                [
                    "aws", "iam", "delete-access-key", "--access-key-id",
                    access_key_id
                ],
                check=True)

    def _purge_keyvault(self):
        subprocess.run(
            [
                "az", "keyvault", "purge", "--subscription",
                self.config.get_config_var("AZURE_SUBSCRIPTION"), "-n",
                self.config.get_config_var("KEY_VAULT_NAME")
            ],
            check=True)
