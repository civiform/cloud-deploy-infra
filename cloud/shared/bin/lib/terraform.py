import subprocess
import os
import re
import shutil
import shlex
import inspect
from typing import Optional

from cloud.shared.bin.lib.config_loader import ConfigLoader
from cloud.shared.bin.lib.print import print


def force_unlock(
        config_loader: ConfigLoader,
        lock_id: str,
        terraform_template_dir: Optional[str] = None):
    if not terraform_template_dir:
        terraform_template_dir = config_loader.get_template_dir()

    perform_init(config_loader, terraform_template_dir, False)

    terraform_cmd = f'terraform -chdir={terraform_template_dir} force-unlock -force {lock_id}'
    print(f" - Run {terraform_cmd}")
    subprocess.check_call(shlex.split(terraform_cmd))
    return True


def perform_init(
        config_loader: ConfigLoader,
        terraform_template_dir: Optional[str] = None,
        upgrade: bool = True):
    if not terraform_template_dir:
        terraform_template_dir = config_loader.get_template_dir()

    init_cmd = f'terraform -chdir={terraform_template_dir} init'
    if upgrade:
        init_cmd += ' -upgrade'

    if config_loader.use_local_backend:
        init_cmd += ' -reconfigure'
    else:
        init_cmd += ' -input=false'
        # backend vars file can be absent when pre-terraform setup is running
        if os.path.exists(os.path.join(terraform_template_dir,
                                       config_loader.backend_vars_filename)):
            init_cmd += f' -backend-config={config_loader.backend_vars_filename}'
    print(f" - Run {init_cmd}")
    #subprocess.check_call(shlex.split(init_cmd))
    output, exit_code = capture_stderr(init_cmd)
    if exit_code:
        # This is AWS-specific, and should be modified when we have actual
        # Azure deployments
        if 'state data in S3 does not have the expected content' in output:
            match = re.search(r'value: ([0-9a-f]{32})', output)
            if match:
                print(
                    f"To fix the above error, rerun this command with \"--fix-digest={match.group(match.lastindex)}\""
                )
            exit(exit_code)


# We specifically don't want to capture stdout here. When running in interactive mode,
# we'd miss the prompt to enter "yes" to continue on a terraform apply, even if we're
# printing each line as it comes in, since the line the prompt is on does not contain
# a new line character.
def capture_stderr(cmd):
    popen = subprocess.Popen(
        shlex.split(cmd),
        stderr=subprocess.PIPE,
        bufsize=1,
        universal_newlines=True)
    try:
        exit_code = popen.wait()
        _, stderr = popen.communicate()
        if stderr:
            print(stderr)
        return stderr, exit_code
    except KeyboardInterrupt:
        # Allow terraform to gracefully exit if a user Ctrl+C's out of the command
        #popen.terminate()
        popen.kill()


# TODO(#2741): When using this for Azure make sure to setup backend bucket prior to calling these functions.
def perform_apply(
        config_loader: ConfigLoader,
        is_destroy=False,
        terraform_template_dir: Optional[str] = None):
    '''Generates terraform variable files and runs terraform init and apply.'''
    if not terraform_template_dir:
        terraform_template_dir = config_loader.get_template_dir()
    tf_vars_filename = config_loader.tfvars_filename

    perform_init(config_loader, terraform_template_dir)

    if os.path.exists(os.path.join(terraform_template_dir, tf_vars_filename)):
        print(
            f'{tf_vars_filename} exists in {terraform_template_dir} directory')
    else:
        raise ValueError(
            f'Aborting the script. {tf_vars_filename} does not exist in {terraform_template_dir} directory'
        )

    if config_loader.is_test():
        print(" - Test. Not applying terraform.")
        return True

    # Enable compact-warnings as we have a bunch of
    # "value of undeclared variables" warnings as some variables used in one
    # deployment (e.g. aws) but not the other.
    terraform_apply_cmd = f'terraform -chdir={terraform_template_dir} apply -input=false -var-file={tf_vars_filename} -compact-warnings'
    if config_loader.skip_confirmations:
        terraform_apply_cmd += ' -auto-approve'
    if is_destroy:
        terraform_apply_cmd += ' -destroy'

    print(f" - Run {terraform_apply_cmd}")

    output, exit_code = capture_stderr(terraform_apply_cmd)
    if exit_code:
        if "Error acquiring the state lock" in output:
            # Lock ID is a standard UUID v4 in the form 00000000-0000-0000-0000-000000000000
            match = re.search(
                    r'ID:\s+([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})',
                    output)
            error_text = inspect.cleandoc(
                """
                                     The Terraform state lock can not be acquired.
                                     This can happen if you are running a command in another process, or if another Terraform process exited prematurely. 
                                     """)
            if match:
                print(
                    error_text +
                    f"\nIf you are sure there are no other Terraform processes running, this can be fixed by rerunning the same command with \"--force-unlock={match.group(match.lastindex)}\""
                )
            else:
                print(
                    error_text +
                    "\nWe were unable to extract the lock ID from the error text. Inspect the error message above."
                    "\nIf you are sure there are no other Terraform processes running, this error can be fixed by rerunning the same command with \"--force-unlock=<Lock ID>\""
                )
        exit(exit_code)

    return True


def copy_backend_override(config_loader: ConfigLoader):
    '''
    Copies the terraform backend_override to backend_override.tf (used to
    make backend local instead of a shared state for dev deploys)
    '''
    backend_override_path = os.path.join(
        config_loader.get_template_dir(), 'backend_override')
    if not os.path.exists(backend_override_path):
        print(f'{backend_override_path} does not exist.')
        return

    shutil.copy(
        backend_override_path,
        os.path.join(config_loader.get_template_dir(), 'backend_override.tf'))
