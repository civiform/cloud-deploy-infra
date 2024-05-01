import sys

from cloud.aws.templates.aws_oidc.bin import resources
from cloud.aws.templates.aws_oidc.bin.aws_cli import AwsCli
from cloud.shared.bin.lib import terraform
from cloud.shared.bin.lib.print import print
from cloud.shared.bin.lib.color import Color


def run(config):
    aws = AwsCli(config)

    if not config.is_test():
        secret_length = aws.get_application_secret_length()
        if secret_length < 32:
            print(
                f'{Color.RED}The application secret must be at least 32 characters in length, and ideally 64 characters. The current secret has a length of {secret_length}. See https://docs.civiform.us/it-manual/sre-playbook/initial-deployment/terraform-deploy-system#rotating-the-application-secret for details on how to regenerate the secret with a longer length.{Color.END}'
            )
            exit(1)

    if not terraform.perform_apply(config):
        print('Terraform deployment failed.')
        # TODO(#2606): write and upload logs.
        raise ValueError('Terraform deployment failed.')

    if config.is_test():
        print('Test completed')
        return

    aws.wait_for_ecs_service_healthy()
    lb_dns = aws.get_load_balancer_dns(f'{config.app_prefix}-civiform-lb')
    base_url = config.get_base_url()
    print(
        f'Server is available at {lb_dns}. Check your domain registrar to ensure your CNAME record for {base_url} points to this address.'
    )
