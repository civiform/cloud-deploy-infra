#! /usr/bin/env python3
from cloud.aws.templates.aws_oidc.bin import resources
from cloud.aws.templates.aws_oidc.bin.aws_cli import AwsCli
from cloud.aws.templates.aws_oidc.bin.aws_template import AwsSetupTemplate
from cloud.shared.bin.lib.print import print


class Destroy(AwsSetupTemplate):
    """
    Destroy the setup
    """

    def post_terraform_destroy(self):
        # when config is dev then the state is stored locally and no clean up
        # required
        if not self.config.use_local_backend:
            print(
                'Not destroying S3 bucket that contains terraform state. ' +
                'You have to destroy it manually:')
            aws_cli = AwsCli(self.config)
            print(
                aws_cli.get_url_of_s3_bucket(
                    f'{self.config.app_prefix}-{resources.S3_TERRAFORM_STATE_BUCKET}'
                ))
