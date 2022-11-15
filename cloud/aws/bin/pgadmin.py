"""Implements the pgadmin command for aws.

This module is dynamically loaded from cloud/shared/bin/run.py.
"""

import os
import sys
import time
import re
import urllib.error
import urllib.request

from enum import Enum
from typing import Callable

from cloud.shared.bin.lib import terraform
from cloud.shared.bin.lib.config_loader import ConfigLoader
from cloud.aws.templates.aws_oidc.bin import resources
from cloud.aws.templates.aws_oidc.bin.aws_cli import AwsCli


def run(config: ConfigLoader):
    os.environ["TF_VAR_pgadmin_cidr_allowlist"] = _get_cidr_list()
    os.environ["TF_VAR_pgadmin"] = "true"
    _run_terraform(config)

    pgurl = f"{config.get_base_url()}:4433"
    print(
        "\npgadmin terraform deployment finished. Waiting for pgadmin service (some request failures are expected):"
    )
    _wait_for_pgadmin_response(pgurl)

    print(f"\npgadmin service is available. URL: {pgurl}")
    _print_secrets(config)

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
    sm = CIDRInputStateMachine(_detect_public_ip)
    user_input = ""
    while True:
        prompt = sm.next(user_input)
        if prompt == "":
            return sm.cidrs()

        user_input = input(prompt)


def _detect_public_ip() -> str:
    try:
        with urllib.request.urlopen("https://checkip.amazonaws.com/",
                                    timeout=3) as response:
            # response contains a newline
            return response.read().decode("ascii").strip()
    except:
        return ""


def _run_terraform(config: ConfigLoader):
    if not terraform.perform_apply(config):
        sys.stderr.write("Terraform deployment failed.")
        raise ValueError("Terraform deployment failed.")


def _wait_for_pgadmin_response(url):
    while True:
        error = ""
        try:
            r = urllib.request.urlopen(f"{url}/misc/ping")
            if r.getcode() != 200:
                error = f"expected HTTP code 200, got {r.getcode()}"
            else:
                break
        except urllib.error.URLError as e:
            error = f"{e}"

        print(f"  {error}. Retrying in 10 seconds...")
        time.sleep(10)


def print_secrets(config):
    aws = AwsCli(config)
    prefix = f"{config.app_prefix}-civiform"
    print(
        f"  pgadmin default email: {aws.get_secret_value(prefix + '-pgadmin-default-username')}\n"
        f"  pgadmin default password: {aws.get_secret_value(prefix + '-pgadmin-default-password')}\n"
        f"  postgres database password: {aws.get_secret_value(prefix + '_postgres_password')}"
    )


UserPrompt = str
UserInput = str
CIDRList = str
PublicIPDetector = Callable[[], str]


class CIDRInputStateMachine:
    """
    State machine for getting a user-input list of CIDR blocks.

    Instantiate the class with a function that returns the public IP
    of the host. The CIDR block list will default to the detected IP.
    Use a function that returns the empty string to disable this feature.

    After instantiating the class, call the next() function in a loop.
    Prompt the user with whatever next() returns and pass in the
    user's input to the following call of next(). When next() returns
    an empty string, the state machine has terminated. Call cidrs() to
    get the resulting CIDR block list, correctly formatted as
    Terraform expects. cidrs() returns an empty string if the state
    machine has not terminated.

           |>-------------------------------IP found----------------------->|
           |                                                                v
    -> DETECT_IP --IP not found--> SET_VALIDATE_FORMAT --valid list--> ACCEPT_LIST --yes--> DONE
                                    ^               |                       |
                                    |--invalid list<|                       |
                                    |                                       |
                                    ^-------------------------no-----------<|
    """

    State = Enum(
        'State', ['DETECT_IP', 'SET_VALIDATE_FORMAT', 'ACCEPT_LIST', 'DONE'])
    # Regexp is from cloud/aws/modules/pgadmin/variables.tf.
    valid_cidr_re = re.compile(
        "^([0-9]{1,3}\\.){3}[0-9]{1,3}(\\/([0-9]|[1-2][0-9]|3[0-2]))$")

    def __init__(self, detect_ip_func: PublicIPDetector):
        self._detect_ip = detect_ip_func
        self._state = self.State.DETECT_IP
        self._cidrs = ""

    def next(self, user_input: UserInput) -> UserPrompt:
        # State transition helpers.
        def goto_input_list():
            self._cidrs = ""
            self._state = self.State.SET_VALIDATE_FORMAT
            return "REQUIRED: input a comma-separated list of IPv4 CIDR blocks that should have access to the pgadmin service.\n> "

        def goto_accept_list(formatted_cidrs):
            self._cidrs = formatted_cidrs
            self._state = self.State.ACCEPT_LIST
            return f"Parsed list: {formatted_cidrs}. Accept? (anything entered other than 'y' will trigger list re-entry) "

        # State transition logic.
        s = self._state
        if s == self.State.DETECT_IP:
            ip = self._detect_ip()
            if ip == "":
                return goto_input_list()
            else:
                return "Public IP detection sucessful. Defaulting pgadmin IPv4 CIDR block allowlist to found IP.\n" + goto_accept_list(
                    f'["{ip}/32"]')
        elif s == self.State.SET_VALIDATE_FORMAT:
            # Validate each block in list.
            errors = ""
            blocks = [x.strip() for x in user_input.split(",")]
            for b in blocks:
                if self.valid_cidr_re.fullmatch(b) == None:
                    errors += f"  {b}\n"
            if errors != "":
                return "ERROR: found invalid CIDR blocks:\n" + errors + "Re-enter CIDR blocks:\n> "

            # Terraform expects lists in the `["item1", "item2", ..., "itemN"]` format:
            # https://developer.hashicorp.com/terraform/language/values/variables#variables-on-the-command-line
            #
            # Notably, single quotes are not valid. Strings in lists formatted in f-strings are wrapped in single
            # quotes so we need to replace them with double quotes.
            return goto_accept_list(f"{blocks}".replace("'", '"'))
        elif s == self.State.ACCEPT_LIST:
            if user_input == "y":
                self._state = self.State.DONE
                return ""
            else:
                return goto_input_list()
        elif s == self.State.DONE:
            return ""

    def cidrs(self) -> CIDRList:
        if self._state == self.State.DONE:
            return self._cidrs
        else:
            return ""
