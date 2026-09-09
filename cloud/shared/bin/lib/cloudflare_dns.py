import os
import shutil
from typing import Optional

from cloud.aws.templates.aws_oidc.bin import resources
from cloud.shared.bin.lib.config_loader import ConfigLoader
from cloud.shared.bin.lib.print import print
from cloud.shared.bin.lib import terraform


def is_dns_enabled(config: ConfigLoader) -> bool:
    """Returns True if Cloudflare DNS management is enabled in configuration."""
    return config.is_cloudflare_dns_enabled


def get_module_dir() -> str:
    """Returns the absolute path to the cloudflare_dns Terraform module."""
    return os.path.join(
        os.getcwd(), 'cloud', 'shared', 'modules', 'cloudflare_dns')


def setup_backend(config: ConfigLoader):
    """Sets up backend configuration for the cloudflare_dns Terraform module."""
    module_dir = get_module_dir()

    if config.use_local_backend:
        backend_override_src = os.path.join(module_dir, 'backend_override')
        backend_override_dest = os.path.join(module_dir, 'backend_override.tf')
        if os.path.exists(backend_override_src):
            shutil.copy(backend_override_src, backend_override_dest)
        return

    backend_file_location = os.path.join(
        module_dir, config.backend_vars_filename)
    with open(backend_file_location, 'w') as f:
        f.write(
            f'bucket         = "{config.app_prefix}-{resources.S3_TERRAFORM_STATE_BUCKET}"\n'
        )
        f.write('key            = "tfstate/cloudflare-dns.tfstate"\n')
        f.write(f'region         = "{config.aws_region}"\n')
        f.write(
            f'dynamodb_table = "{config.app_prefix}-{resources.S3_TERRAFORM_LOCK_TABLE}"\n'
        )
        f.write('encrypt        = true\n')


def write_tfvars(config: ConfigLoader, target_dns: str):
    """Writes the setup.auto.tfvars file for the cloudflare_dns module."""
    module_dir = get_module_dir()
    tfvars_path = os.path.join(module_dir, config.tfvars_filename)

    api_token_secret_id = (
        config.get_config_var('CLOUDFLARE_API_TOKEN_SECRET_ARN') or
        f'{config.app_prefix}-{resources.CLOUDFLARE_API_TOKEN_SECRET}')
    zone_id = config.get_config_var('CLOUDFLARE_ZONE_ID') or ''
    record_name = config.get_config_var('CLOUDFLARE_RECORD_NAME') or ''
    ttl = config.get_config_var('CLOUDFLARE_TTL') or 1
    proxied = config.get_config_var('CLOUDFLARE_PROXIED') or 'false'
    proxied_val = 'true' if str(proxied).lower() == 'true' else 'false'

    with open(tfvars_path, 'w') as f:
        # codeql[py/clear-text-storage-sensitive-data] The API token is stored in AWS Secrets Manager. This value is just the ARN or Key of said secret.
        f.write(f'cloudflare_api_token_secret_id = "{api_token_secret_id}"\n')
        f.write(f'aws_region                     = "{config.aws_region}"\n')
        f.write(f'cloudflare_zone_id             = "{zone_id}"\n')
        f.write(f'record_name                    = "{record_name}"\n')
        f.write(f'target_dns_name                = "{target_dns}"\n')
        f.write(f'app_prefix                     = "{config.app_prefix}"\n')
        f.write(f'ttl                            = {ttl}\n')
        f.write(f'proxied                        = {proxied_val}\n')


def apply_dns(config: ConfigLoader, target_dns: str) -> bool:
    """Applies the cloudflare_dns Terraform configuration to create or update the DNS record."""
    if not is_dns_enabled(config):
        return True

    record_name = config.get_config_var('CLOUDFLARE_RECORD_NAME')
    print(f'\nManaging DNS record in Cloudflare: {record_name} -> {target_dns}')

    module_dir = get_module_dir()
    setup_backend(config)
    write_tfvars(config, target_dns)

    success = terraform.perform_apply(
        config,
        is_destroy=False,
        terraform_template_dir=module_dir,
    )

    if success:
        print(
            f'Successfully configured Cloudflare DNS record: {record_name} -> {target_dns}'
        )
    else:
        print('Failed to apply Cloudflare DNS record.')

    return success


def destroy_dns(config: ConfigLoader) -> bool:
    """Destroys the cloudflare_dns Terraform resources."""
    if not is_dns_enabled(config):
        return True

    record_name = config.get_config_var('CLOUDFLARE_RECORD_NAME')
    print(f'\nDestroying Cloudflare DNS record: {record_name}')

    module_dir = get_module_dir()
    setup_backend(config)
    # Write tfvars if not present to allow terraform destroy to evaluate provider
    tfvars_path = os.path.join(module_dir, config.tfvars_filename)
    if not os.path.exists(tfvars_path):
        write_tfvars(config, target_dns='dummy-target')

    return terraform.perform_apply(
        config,
        is_destroy=True,
        terraform_template_dir=module_dir,
    )
