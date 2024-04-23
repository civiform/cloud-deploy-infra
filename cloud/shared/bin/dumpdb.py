import importlib
import os
from typing import List

from cloud.shared.bin.lib.config_loader import ConfigLoader


def run(config: ConfigLoader, params: List[str]):
    source = os.path.join(
        "cloud", config.get_cloud_provider(), "bin", "dumpdb.py")
    if os.path.exists(source):
        deploy_module = importlib.import_module(
            f"cloud.{config.get_cloud_provider()}.bin.dumpdb")
        deploy_module.run(config)
    else:
        exit(
            f"dumpdb command not implemented for {config.get_cloud_provider()}")
