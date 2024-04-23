import os
import ipaddress
import sys
import tempfile
import shlex
import subprocess
import textwrap
import urllib.request
from pathlib import Path
from time import sleep
from datetime import datetime

from cloud.aws.templates.aws_oidc.bin import resources
from cloud.aws.templates.aws_oidc.bin.aws_cli import AwsCli
from cloud.shared.bin.lib import terraform
from cloud.shared.bin.lib.config_loader import ConfigLoader
from cloud.shared.bin.lib.print import print


class Color:
    RED = '\033[31m'
    GREEN = '\033[32m'
    YELLOW = '\033[33m'
    END = '\033[0m'


def run(config: ConfigLoader):
    aws = AwsCli(config)
    print(
        textwrap.dedent(
            f"""
            {Color.RED}!!! WARNING !!!: This command will overwrite the entire database with the contents of the dump file. Ensure this is really what you want to do before proceeding. 
            
            You should ideally only restore the database to the same version of CiviForm that the dump was taken from. Restoring an older database to a newer CiviForm version may work, but may require additional steps, such as redeploying the application. Restoring a newer database dump to an older CiviForm version is not supported.
            
            Additionally, any files uploaded as part of applications that were submitted after the time of the database dump will become orphaned and may need to be manually cleaned up.{Color.END}

            The input to this command is expected to be a dump file generated via the 'dumpdb' command. This process will set up a temporary EC2 host with access to the database, use SCP to copy the dump file to that host, then SSH to run the pg_restore command.

            If something goes wrong and this process is interrupted before it tears down the resources, you can find them all with the "Module = dbaccess" tag in the AWS console. They should be deleted manually.

            The "ssh" and "ssh-keygen" commands must be available on your machine, typically provided by the openssh-client package. If you do not have these commands, you will need to install them before proceeding.
        """))
    answer = input('Do you understand the risks and wish to proceed? (y/N): ')
    if answer.lower() != 'y':
        print('Exiting.')
        return

    while True:
        dumpfile = input('Enter the full path of the dump file to restore: ')
        if not os.path.isfile(dumpfile):
            print(
                f'{Color.YELLOW}File not found. Please verify the path and try again.{Color.END}'
            )
            continue
        with open(dumpfile, 'rb') as f:
            if f.read(5) != b'PGDMP':
                answer = input(
                    f'{Color.YELLOW}File does not appear to be a valid PostgreSQL dump file. Are you sure you wish to use this file? (y/N): {Color.END}'
                )
                if answer.lower() == 'y':
                    break
            else:
                break

    with tempfile.TemporaryDirectory(dir=Path.cwd()) as tmpdir:
        print(f'Generating key pair in {tmpdir}')
        _run_cmd(f'ssh-keygen -t rsa -b 4096 -f {tmpdir}/dbaccess -N ""')
        _run_cmd(f'chmod 600 {tmpdir}/dbaccess')

        print('Deploying dbaccess instance')
        os.environ[
            'TF_VAR_dbaccess_cidr_allowlist'] = f'["{_detect_public_ip()}/32"]'
        os.environ['TF_VAR_dbaccess'] = "true"
        os.environ['TF_VAR_dbaccess_public_key'] = f'{tmpdir}/dbaccess.pub'

        try:
            _run_terraform(config)

            ec2_host_ip = aws.get_dbaccess_ec2_host_ip()
            print(f'EC2 host IP is {ec2_host_ip}')

            db_hostname = aws.get_database_hostname()
            db_user = aws.get_secret_value(
                config.app_prefix + '-civiform_postgres_username')
            db_pwd = aws.get_secret_value(
                config.app_prefix + '-civiform_postgres_password')

            args = f'-o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" -o "IdentitiesOnly=yes" -i {tmpdir}/dbaccess'
            ssh = f'ssh -q {args} "ubuntu@{ec2_host_ip}" '

            # We typically need about 15 seconds before the EC2 instance is ready
            # to accept SSH connections.
            print('Waiting for SSH access to EC2 host to become available')
            sleep(15)
            while True:
                try:
                    _run_cmd(ssh + 'exit', quiet=True)
                    break
                except subprocess.CalledProcessError as e:
                    if e.returncode == 255:
                        print(
                            'SSH connection failed. Retrying in 10 seconds...')
                        sleep(10)
                    else:
                        raise e

            print('Installing postgresql-client')
            cmd = ssh + '"sudo apt-get update && sudo apt-get install -y postgresql-client"'
            _run_cmd(cmd)

            print('Creating .pgpass file and SCPing to EC2 host')
            pgpass = f'{tmpdir}/.pgpass'
            with open(pgpass, 'w') as f:
                f.write(f"{db_hostname}:5432:*:{db_user}:{db_pwd}\n")
            _run_cmd(f'chmod 600 {pgpass}')
            cmd = f'scp {args} "{pgpass}" "ubuntu@{ec2_host_ip}:.pgpass"'
            _run_cmd(cmd)
            _run_cmd(f'rm -f {pgpass}')

            print('SCPing dump file to EC2 host')
            cmd = f'scp {args} "{dumpfile}" "ubuntu@{ec2_host_ip}:civiform_database.dump"'
            _run_cmd(cmd)

            # Do the restore
            cmd = ssh + f"pg_restore --no-password --host='{db_hostname}' --username='{db_user}' --dbname=postgres --clean --exit-on-error civiform_database.dump"
            _run_cmd(cmd)

            # Not strictly necessary, but in case the host sticks around for some reason.
            print('Delete dump file and pgpass file on EC2 host')
            cmd = ssh + 'rm -f civiform_database.dump'
            _run_cmd(cmd)
            cmd = ssh + 'rm -f .pgpass'
            _run_cmd(cmd)

            input(
                f'{Color.GREEN}Database restore complete. Press Enter to tear down the temporary resources.{Color.END}'
            )
        except:
            input(
                f"\n{Color.RED}Error occurred. See details above. Press Enter to tear down the temporary resources.{Color.END}"
            )
            raise
        finally:
            print('Cleaning up resources')
            os.unsetenv("TF_VAR_dbaccess_cidr_allowlist")
            os.unsetenv("TF_VAR_dbaccess")
            _run_terraform(config)


def _detect_public_ip() -> str:
    try:
        with urllib.request.urlopen("https://checkip.amazonaws.com",
                                    timeout=3) as response:
            # response contains a newline
            ip = response.read().decode("ascii").strip()
            ipaddress.IPv4Address(ip)
            return ip
    except:
        print(
            f'{Color.YELLOW}Unable to find the public IP of this machine using checkip.amazonaws.com.{Color.END}'
        )
        return _ask_for_ip()


def _ask_for_ip() -> str:
    while True:
        answer = input('Please enter the public IP of this machine: ').strip()
        try:
            ipaddress.IPv4Address(answer)
            return answer
        except ValueError:
            print(
                f'{Color.YELLOW}Invalid IP address. Please try again.{Color.END}'
            )


def _run_cmd(cmd, quiet=False):
    while True:
        try:
            subprocess.check_output(shlex.split(cmd), stderr=subprocess.STDOUT)
            break
        except subprocess.CalledProcessError as e:
            if not quiet:
                print(Color.RED)
                print('Error running command:')
                print("Command:", e.cmd)
                print("Return code:", e.returncode)
                print("Output:", e.output.decode())
                print(Color.END)
            raise e


def _run_terraform(config: ConfigLoader):
    if not terraform.perform_apply(config):
        sys.stderr.write("Terraform deployment failed.")
        raise ValueError("Terraform deployment failed.")
