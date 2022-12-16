import sys

from cloud.aws.templates.aws_oidc.bin import resources
from cloud.aws.templates.aws_oidc.bin.aws_cli import AwsCli
from cloud.shared.bin.lib import terraform


def run(config):
    if not terraform.perform_apply(config):
        sys.stderr.write('Terraform deployment failed.')
        # TODO(#2606): write and upload logs.
        raise ValueError('Terraform deployment failed.')

    if config.is_test():
        print('Test completed')
        return

    aws = AwsCli(config)
    aws.wait_for_ecs_service_healthy()
