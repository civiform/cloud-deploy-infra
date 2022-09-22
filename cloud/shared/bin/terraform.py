"""
Run terraform commands.
"""

import subprocess
from typing import List
from cloud.shared.bin.lib.config_loader import ConfigLoader
from cloud.shared.bin.lib import terraform


def run(config: ConfigLoader, params: List[str]):
    if not params:
        exit('terraform command requires arguments, but none were provided.')
    subprocess.check_call(
        ['terraform', f'-chdir={config.get_template_dir()}'], 'init')
    subprocess.check_call(
        ['terraform', f'-chdir={config.get_template_dir()}'] + params)
