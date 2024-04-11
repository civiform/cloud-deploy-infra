"""Implements the pgadmin command for aws.

This module is dynamically loaded from cloud/shared/bin/run.py.
"""

import os
import sys
import time
import urllib.error
import urllib.request

from cloud.aws.templates.aws_oidc.bin.aws_cli import AwsCli
from cloud.shared.bin.lib import terraform
from cloud.shared.bin.lib.config_loader import ConfigLoader
from cloud.shared.bin.lib.print import print
from cloud.shared.cidr_state_machine import CIDRInputStateMachine


def run(config: ConfigLoader):
    os.environ["TF_VAR_pgadmin_cidr_allowlist"] = _get_cidr_list()
    os.environ["TF_VAR_pgadmin"] = "true"
    import pdb
    pdb.set_trace()
    _run_terraform(config)

    url = f"{config.get_base_url()}:4433"
    print(
        "\npgadmin terraform deployment finished. Waiting for pgadmin to be available (some request failures are expected). Press ctrl-c to shortcut this wait and print connection information."
    )
    _wait_for_pgadmin_response(url)
    _print_connection_info(config, url)

    input(
        "\nWARNING: it is strongly recommended to clean up pgadmin resources once they are no-longer needed.\n"
        f"Run 'bin/deploy' to manually clean up pgadmin resources.\n\n"
        "Waiting to clean up pgadmin resources.  Press enter to trigger cleanup...\n"
    )
    os.unsetenv("TF_VAR_pgadmin_cidr_allowlist")
    os.unsetenv("TF_VAR_pgadmin")
    _run_terraform(config)


def _get_cidr_list() -> str:
    """Runs the CIDRInputStateMachine until the end state is reached."""
    print(
        "\nREQUIRED: configure IPv4 CIDR allow-list for pgadmin. The public IP of the host running the\n"
        "web browser used to access pgadmin is required to be covered by a CIDR block in the list.\n\n"
        "The public IP of the host running this tool is optional and allows the tool to wait until\n"
        "pgadmin is available to print out connection information. This wait is cancellable. If the\n"
        "tool is able to auto-detect its public IP, it will add it to the allow-list by default.\n\n"
        "Visit https://checkip.amazonaws.com to find the public IP of a host running a web browser.\n"
        "To add just a single IP to the allow-list, add a CIDR block like '172.0.0.1/32'.\n"
    )

    sm = CIDRInputStateMachine()
    user_input = ""
    while True:
        prompt = sm.next(user_input)
        if prompt == "":
            return sm.cidrs()

        user_input = input(prompt)


def _run_terraform(config: ConfigLoader):
    if not terraform.perform_apply(config):
        sys.stderr.write("Terraform deployment failed.")
        raise ValueError("Terraform deployment failed.")


def _wait_for_pgadmin_response(url):
    try:
        while True:
            error = ""
            try:
                r = urllib.request.urlopen(f"{url}/misc/ping")
                if r.getcode() != 200:
                    error = f"expected HTTP code 200, got {r.getcode()}"
                else:
                    print(f"\npgadmin service is available.")
                    break
            except urllib.error.URLError as e:
                error = f"{e}"

            print(f"  {error}. Retrying in 10 seconds...")
            time.sleep(10)
    except KeyboardInterrupt:
        print("Cancelled waiting for pgadmin availability. Moving on...")


def _print_connection_info(config, url):
    aws = AwsCli(config)
    prefix = f"{config.app_prefix}"
    print(
        f"\npgamdin connection info:\n"
        f"  URL: {url}\n"
        f"  login email: {aws.get_secret_value(prefix + '-cf-pgadmin-default-username')}\n"
        f"  login password: {aws.get_secret_value(prefix + '-cf-pgadmin-default-password')}\n"
        f"  database password: {aws.get_secret_value(prefix + '-civiform_postgres_password')}"
    )
