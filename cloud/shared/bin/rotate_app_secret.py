import importlib
import os
import sys
from typing import List

from cloud.shared.bin.lib.config_loader import ConfigLoader


def run(config: ConfigLoader, _params: List[str]):
    rotate_file_py = os.path.join(
        'cloud', config.get_cloud_provider(), 'bin', 'rotate_app_secret.py')
    # TODO(#2741): remove the fork after we remove non-Python scripts
    if os.path.exists(rotate_file_py):
        rotate_module = importlib.import_module(
            f'cloud.{config.get_cloud_provider()}.bin.rotate_app_secret')
        if sys.stdin.isatty():
            answer = input(
                "WARNING: Rotating the app secret will invalidate all existing sessions. Any guest users with an unsubmitted application in progress will lose their application, and logged in users and admins will need to log in again. Are you sure you want to continue? [y/N]: "
            )
            if answer.lower() in ['y', 'yes']:
                rotate_module.run(config)
            else:
                exit('Aborting app secret rotation.')
    else:
        exit(
            f'Could not find rotate_app_secret.py for {config.get_cloud_provider()}'
        )
