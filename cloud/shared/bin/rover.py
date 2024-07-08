"""
Run rover.
"""

import subprocess
from typing import List
from cloud.shared.bin.lib.config_loader import ConfigLoader


def run(config: ConfigLoader, params: List[str]):
    td = config.get_template_dir()
    subprocess.check_call(
        [
            "rover",
            f"-workingDir=/{td}",
            f"-tfVarsFile=/{td}/{config.tfvars_filename}",
            f"-tfBackendConfig=/{td}/{config.backend_vars_filename}",
        ]
    )
