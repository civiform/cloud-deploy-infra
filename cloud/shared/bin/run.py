#! /usr/bin/env python3

import argparse
import shlex
import os
import sys
import importlib
import re

# Need to add current directory to PYTHONPATH if this script is run directly.
sys.path.append(os.getcwd())

from cloud.shared.bin.lib.config_loader import ConfigLoader
from cloud.shared.bin.lib.print import print
from cloud.shared.bin.lib import backend_setup
from cloud.shared.bin.lib import terraform
from cloud.aws.templates.aws_oidc.bin.aws_cli import AwsCli

_CIVIFORM_RELEASE_TAG_REGEX = re.compile(r'^v?[0-9]+\.[0-9]+\.[0-9]+$')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '--tag', help='Civiform image tag. Required for Setup and Deploy.')
    parser.add_argument(
        '--command',
        help='Command to run. If omitted, will validate config and exit.')
    parser.add_argument(
        '--config',
        default='civiform_config.sh',
        help='Path to CiviForm deployment config file.')
    parser.add_argument(
        '--force-unlock',
        help='Lock ID to force unlock before performing the Terraform apply.')
    parser.add_argument(
        '--lock-table-digest-value',
        help=
        'Digest value for the Terraform lock table to set in DynamoDB. If multiple processes are doing a deploy, or an error occurred in a previous deploy that prevented Terraform from cleaning up after itself, this value may need updating. Only works on AWS deployments.'
    )

    args = parser.parse_args()
    if args.tag:
        if not validate_tag(args.tag):
            exit()
        os.environ['TF_VAR_image_tag'] = normalize_tag(args.tag)
        print(f'Running command with tag {os.environ["TF_VAR_image_tag"]}\n')
    elif args.command is not None and args.command in ['setup', 'deploy']:
        exit('--tag is required')

    os.environ['TERRAFORM_PLAN_OUT_FILE'] = 'terraform_plan'

    config = ConfigLoader()
    validation_errors = config.load_config(args.config)
    if validation_errors:
        new_line = '\n\t'
        exit(
            f'Found the following validation errors: {new_line}{f"{new_line}".join(validation_errors)}'
        )

    # Setup backend
    backend_setup.setup_backend(config)

    # Run the command to force unlock the TF state lock
    if args.force_unlock:
        print("Force unlocking the Terraform state")
        terraform.force_unlock(config, args.force_unlock)

    if args.lock_table_digest_value:
        print(
            f"Fixing the lock file digest value in DynamoDB, setting it to {args.lock_table_digest_value}"
        )
        aws = AwsCli(config)
        aws.set_lock_table_digest_value(args.lock_table_digest_value)

    # Write the passthrough vars to a temporary file
    print("Writing TF Vars file")
    config.write_tfvars_file()

    if args.command:
        cmd = shlex.split(args.command)[0]
        params = shlex.split(args.command)[1:]
        if not os.path.exists(f'cloud/shared/bin/{cmd}.py'):
            exit(f'Command {cmd} not found.')
        command_module = importlib.import_module(f'cloud.shared.bin.{cmd}')
        if not command_module:
            exit(f'Command {cmd} not found.')
        command_module.run(config, params)


def validate_tag(tag):
    if _CIVIFORM_RELEASE_TAG_REGEX.match(tag):
        return True

    print(
        f'''
        The provided tag "{tag}" does not reference a release tag and may not
        be stable.
        ''')
    if os.getenv('SKIP_USER_INPUT'):
        print(
            'Proceeding automatically since the "SKIP_USER_INPUT" environment variable was set.'
        )
        return True
    print(
        f'''
        If you would like to continue deployment, please type YES below.
        Continue: ''',
        end='',
        flush=True)
    resp = input()
    return resp.lower().strip() == 'yes'


def normalize_tag(tag):
    if _CIVIFORM_RELEASE_TAG_REGEX.match(tag) and not tag[0] == 'v':
        return f'v{tag}'
    return tag


if __name__ == "__main__":
    main()
