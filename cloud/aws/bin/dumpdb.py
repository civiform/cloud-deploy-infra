import os
import ipaddress
import sys
import tempfile
import shlex
import subprocess
from time import sleep
from datetime import datetime
import urllib.request

from cloud.aws.templates.aws_oidc.bin import resources
from cloud.aws.templates.aws_oidc.bin.aws_cli import AwsCli
from cloud.shared.bin.lib import terraform
from cloud.shared.bin.lib.config_loader import ConfigLoader
from cloud.shared.bin.lib.print import print


def run(config: ConfigLoader):
    aws = AwsCli(config)
    print(
        "\n"
        "\033[31m!!! WARNING !!!: This command will create a dump of the entire database, including personally identifiable information (PII). Ensure you take the utmost care in handling this data and store it in a secure location.\033[0m\n"
        "\n"
        'This process will set up a temporary EC2 host with access to the database, use SSH to run the pg_dump command on that host, then SCP the file to this machine. '
        'You will need to confirm the application of the Terraform manifest that creates these temporary resources, and then confirm the teardown of these resources. '
        'If something goes wrong and this process is interrupted before it tears down the resources, you can find them all with the "Module = dbaccess" tag in the AWS console. They should be deleted manually.'
        "\n\n"
        'The "ssh" and "ssh-keygen" commands must be available on your machine, typically provided by the openssh-client package. If you do not have these commands, you will need to install them before proceeding.'
        "\n\n")
    answer = input('Do you understand the risks and wish to proceed? (y/N): ')
    if answer.lower() != 'y':
        print('Exiting.')
        return

    timestamp = datetime.now().strftime('%Y-%m-%d_%H-%M-%S')

    # Current working dir should be the 'checkout' folder, so go one level above.
    default_file = os.path.join(
        os.path.dirname(os.getcwd()),
        f'{config.app_prefix}_civiform_database_{timestamp}.dump')
    dumpfile = input(
        f"Enter the location to save the dump file (default: {default_file}): "
    ) or default_file

    dumpdir = os.path.dirname(dumpfile)
    if not os.path.isdir(dumpdir):
        os.makedirs(dumpdir)
        print(f'Directory created: {dumpdir}')

    # Generate a new key pair for the dbaccess instance. We'll
    # save this to a temp directory and run all the critical pieces
    # inside this block so we ensure the key is cleaned up.
    with tempfile.TemporaryDirectory(dir=dumpdir) as tmpdir:
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

            print('Generating dump file')
            cmd = ssh + f"pg_dump --no-password --format=custom --host='{db_hostname}' --username='{db_user}' --dbname=postgres > civiform_database.dump"
            _run_cmd(cmd)

            print('Downloading dump file to local machine')
            cmd = f'scp {args} "ubuntu@{ec2_host_ip}:/home/ubuntu/civiform_database.dump" {dumpfile}'
            _run_cmd(cmd)

            # Not strictly necessary, but in case the host sticks around for some reason.
            print('Delete dump file and pgpass file on EC2 host')
            cmd = ssh + 'rm -f civiform_database.dump'
            _run_cmd(cmd)
            cmd = ssh + 'rm -f .pgpass'
            _run_cmd(cmd)

            input(
                '\033[32mDatabase dump complete. Press Enter to tear down the temporary resources.\033[0m'
            )
        except:
            input(
                "\n\033[31mError occurred. See details above. Press Enter to tear down the temporary resources.\033[0m"
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
            'Unable to find the public IP of this machine using checkip.amazonaws.com.'
        )
        return _ask_for_ip()


def _ask_for_ip() -> str:
    while True:
        answer = input('Please enter the public IP of this machine: ').strip()
        try:
            ipaddress.IPv4Address(answer)
            return answer
        except ValueError:
            print('Invalid IP address. Please try again.')


def _run_cmd(cmd, quiet=False):
    while True:
        try:
            subprocess.check_output(shlex.split(cmd), stderr=subprocess.STDOUT)
            break
        except subprocess.CalledProcessError as e:
            if not quiet:
                print('Error running command:')
                print("Command:", e.cmd)
                print("Return code:", e.returncode)
                print("Output:", e.output.decode())
            raise e


def _run_terraform(config: ConfigLoader):
    if not terraform.perform_apply(config):
        sys.stderr.write("Terraform deployment failed.")
        raise ValueError("Terraform deployment failed.")
