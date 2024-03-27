"""
destroy_backend_state_resources.py destroys the Terraform backend state resources that are used to track 
resources created in the cloud provider during deployment. You may wish to destroy the backend state resources
if they get corrupted.
"""
from typing import List

from cloud.shared.bin.lib.config_loader import ConfigLoader
from cloud.shared.bin.lib.setup_class_loader import get_config_specific_setup


def run(config: ConfigLoader, params: List[str]):
    template = get_config_specific_setup(config)
    resources = template.detect_backend_state_resources()
    if resources['bucket'] or resources['table']:
        print(' - Found resources to destroy. Destroying backend resources...')
        if template.destroy_backend_resources(resources):
            print('Successfully destroyed backend state resources.')
        else:
            print(
                'One or more errors occurred when attempting to delete Terraform backend state resources. Please check your cloud provider\'s console for more information.'
            )
    else:
        print('No backend state resources found to destroy.')