import os
from cloud.aws.templates.aws_oidc.bin import resources
from cloud.shared.bin.lib import terraform


def setup_backend_config(config):
    if config.use_local_backend:
        terraform.copy_backend_override(config)
        return
    backend_file_location = os.path.join(
        config.get_template_dir(), config.backend_vars_filename)
    with open(backend_file_location, 'w') as f:
        f.write(
            f'bucket         = "{config.app_prefix}-{resources.S3_TERRAFORM_STATE_BUCKET}"\n'
        )
        f.write(f'key            = "tfstate/terraform.tfstate"\n')
        f.write(f'region         = "{config.aws_region}"\n')
        f.write(
            f'dynamodb_table = "{config.app_prefix}-{resources.S3_TERRAFORM_LOCK_TABLE}"\n'
        )
        f.write(f'encrypt        = true\n')
