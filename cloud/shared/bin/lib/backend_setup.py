import subprocess
from cloud.shared.bin.lib.config_loader import ConfigLoader
from cloud.aws.bin.lib import backend_setup


def setup_backend(config: ConfigLoader):
    if (config.get_cloud_provider() == 'aws'):
        backend_setup.setup_backend_config(config)
    elif (config.get_cloud_provider() == 'azure'):
        subprocess.check_call(
            [
                'cloud/azure/bin/setup_tf_shared_state',
                f'{config.get_template_dir()}/{config.backend_vars_filename}'
            ])
