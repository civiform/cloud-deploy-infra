import importlib
import os
from typing import List

from cloud.shared.bin.lib.config_loader import ConfigLoader


def run(config: ConfigLoader, _params: List[str]):
    rotate_file_py = os.path.join(
        'cloud', config.get_cloud_provider(), 'bin', 'rotate_app_secret.py')
    # TODO(#2741): remove the fork after we remove non-Python scripts
    if os.path.exists(rotate_file_py):
        rotate_module = importlib.import_module(
            f'cloud.{config.get_cloud_provider()}.bin.rotate_app_secret')
        rotate_module.run(config)
    else:
        exit(
            f'Could not find rotate_app_secret.py for {config.get_cloud_provider()}'
        )
