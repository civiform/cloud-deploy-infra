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
from cloud.shared.bin.lib.write_tfvars import TfVarWriter
from cloud.shared.bin.lib import backend_setup

_CIVIFORM_RELEASE_TAG_REGEX = re.compile(r'^v?[0-9]+\.[0-9]+\.[0-9]+$')


def main():
    if not os.getenv("GITHUB_ACTIONS") == "true":
        _overwrite_checkout_file()

    parser = argparse.ArgumentParser()
    parser.add_argument(
        '--tag', help='Civiform image tag. Required for Setup and Deploy.')
    parser.add_argument(
        '--command',
        help='Command to run. If ommited will validate config and exit.')
    parser.add_argument(
        '--config',
        default='civiform_config.sh',
        help='Path to CiviForm deployment config file.')

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

    # Write the passthrough vars to a temporary file
    print("Writing TF Vars file")
    terraform_tfvars_path = os.path.join(
        config.get_template_dir(), config.tfvars_filename)
    tf_var_writter = TfVarWriter(terraform_tfvars_path)
    tf_var_writter.write_variables(config.get_terraform_variables())

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
    if os.getenv('SKIP_TAG_CHECK'):
        print(
            'Proceeding automatically since the "SKIP_TAG_CHECK" environment variable was set.'
        )
        return True
    print(
        f'''
        If you would like to continue deployment, please type YES below.
        Continue: ''')
    resp = input()
    return resp.lower().strip() == 'yes'


def normalize_tag(tag):
    if _CIVIFORM_RELEASE_TAG_REGEX.match(tag) and not tag[0] == 'v':
        return f'v{tag}'
    return tag


def _overwrite_checkout_file():
    # Read in the file
    with open('../bin/lib/checkout.sh', 'r') as file:
        filedata = file.read()

    # Replace args and command path name
    filedata = filedata.replace(
        'args=("-c${CMD_NAME}" "-t${CIVIFORM_VERSION}" "-s${CONFIG_FILE_ABSOLUTE_PATH}")',
        'args=("--command=${CMD_NAME}" "--tag=${CIVIFORM_VERSION}" "--config=${CONFIG_FILE_ABSOLUTE_PATH}")'
    )
    filedata = filedata.replace(
        'CMD_NAME_PATH="cloud/shared/bin/run"',
        'CMD_NAME_PATH="cloud/shared/bin/run.py"'
        )

    # Write the file out again
    with open('../bin/lib/checkout.sh', 'w') as file:
        file.write(filedata)


if __name__ == "__main__":
    main()
