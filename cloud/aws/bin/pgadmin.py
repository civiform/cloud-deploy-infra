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
from typing import Callable, List

from cloud.shared.bin.lib import terraform
from cloud.shared.bin.lib.config_loader import ConfigLoader
from cloud.aws.templates.aws_oidc.bin import resources
from cloud.aws.templates.aws_oidc.bin.aws_cli import AwsCli


def run(config: ConfigLoader):
    os.environ["TF_VAR_pgadmin_cidr_allowlist"] = _get_cidr_list()
    os.environ["TF_VAR_pgadmin"] = "true"
    _run_terraform(config)

    url = f"{config.get_base_url()}:4433"
    print(
        "\npgadmin terraform deployment finished. Waiting for pgadmin to be available (some request failures are expected). Press ctlr-c to shortcut this wait and print connection information."
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

    sm = CIDRInputStateMachine(_detect_public_ip)
    user_input = ""
    while True:
        prompt = sm.next(user_input)
        if prompt == "":
            return sm.cidrs()

        user_input = input(prompt)


def _detect_public_ip() -> str:
    try:
        with urllib.request.urlopen("https://checkip.amazonaws.com",
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
    prefix = f"{config.app_prefix}-civiform"
    print(
        f"\npgamdin connection info:\n"
        f"  URL: {url}\n"
        f"  login email: {aws.get_secret_value(prefix + '-pgadmin-default-username')}\n"
        f"  login password: {aws.get_secret_value(prefix + '-pgadmin-default-password')}\n"
        f"  database password: {aws.get_secret_value(prefix + '_postgres_password')}"
    )


UserPrompt = str
UserInput = str
CIDRList = str
PublicIPDetector = Callable[[], str]


class CIDRInputStateMachine:
    """
    State machine for getting a user-input list of CIDR blocks.

    Instantiate the class with a function that returns the public IP
    of the host. If the function returns a non-empty string, the user
    will be asked if they would like to add the IP to the allow-list.
    Use a function that returns the empty string to disable this feature.

    After instantiating the class, call the next() function in a loop.
    Prompt the user with whatever next() returns and pass in the
    user's input to the following call of next(). When next() returns
    an empty string, the state machine has terminated. Call cidrs() to
    get the resulting CIDR block list, correctly formatted as
    Terraform expects. cidrs() returns an empty string if the state
    machine has not terminated.

           |>--IP found--> ADD_DETECTED_IP --yes--> APPEND_VALIDATE_FORMAT --|
           |                          |              |                       |
           |                          no        invalid list             valid list
           |                          |              |                       |
           |                          v              v                       v
    -> DETECT_IP ---IP not found---> SET_VALIDATE_FORMAT ---valid list---> ACCEPT_LIST --yes--> DONE
                                      ^              |                       |
                                      |-invalid list<|                       |
                                      |                                      |
                                      ^-------------------------no----------<|
    """

    State = Enum(
        'State', [
            'DETECT_IP', 'ADD_DETECTED_IP', 'APPEND_VALIDATE_FORMAT',
            'SET_VALIDATE_FORMAT', 'ACCEPT_LIST', 'DONE'
        ])
    # Regexp is from cloud/aws/modules/pgadmin/variables.tf.
    valid_cidr_re = re.compile(
        "^([0-9]{1,3}\\.){3}[0-9]{1,3}(\\/([0-9]|[1-2][0-9]|3[0-2]))$")

    def __init__(self, detect_ip_func: PublicIPDetector):
        self._detect_ip = detect_ip_func
        self._state = self.State.DETECT_IP
        self._ip = ""
        self._cidrs = ""

    def next(self, user_input: UserInput) -> UserPrompt:
        input_blocks_msg = "Input a comma-separated list of CIDR blocks to add to the allow-list:\n> "

        def process_input(input: str) -> str:
            blocks, errors = CIDRInputStateMachine._parse_blocks(input)
            if errors != "":
                return f"ERROR: found invalid CIDR blocks:\n{errors}\nRe-enter CIDR blocks:\n> "
            if len(blocks) == 0:
                return f"ERROR: allow-list must not be empty.\nRe-enter CIDR blocks:\n> "

            self._cidrs = CIDRInputStateMachine._format_blocks(blocks)
            self._state = self.State.ACCEPT_LIST
            return f"Allow-list: {self._cidrs}.\nAccept? (anything entered other than 'y' triggers list re-entry) > "

        # State transition logic.
        s = self._state
        if s == self.State.DETECT_IP:
            ip = self._detect_ip()
            if ip != "":
                self._ip = ip
                self._state = self.State.ADD_DETECTED_IP
                return f"Detected IP of the host running the deploy tool: {ip}\nAdd to allow-list? (anything entered other than 'y' is a no) > "
            else:
                self._state = self.State.SET_VALIDATE_FORMAT
                return f"Unable to detect IP of the host running the deploy tool.\n{input_blocks_msg}"

        elif s == self.State.ADD_DETECTED_IP:
            if user_input == "y":
                self._state = self.State.APPEND_VALIDATE_FORMAT
                return f"IP added. {input_blocks_msg}"
            else:
                self._ip = ""
                self._state = self.State.SET_VALIDATE_FORMAT
                return f"Ignoring IP. {input_blocks_msg}"

        elif s == self.State.APPEND_VALIDATE_FORMAT:
            return process_input(f"{self._ip}/32,{user_input}")

        elif s == self.State.SET_VALIDATE_FORMAT:
            return process_input(user_input)

        elif s == self.State.ACCEPT_LIST:
            if user_input == "y":
                self._state = self.State.DONE
                return ""
            else:
                self._ip = ""
                self._cidrs = ""
                self._state = self.State.SET_VALIDATE_FORMAT
                return input_blocks_msg

        elif s == self.State.DONE:
            return ""

    # Parses comma-separated CIDR blocks in a string.
    #
    # A formatted list of invalid blocks will be returned in the second
    # tuple slot if any are present.
    def _parse_blocks(input: str) -> (List[str], str):
        # Validate each block in list.
        errors = ""
        blocks = []
        for b in input.split(","):
            b = b.strip()
            if b == "":
                continue
            if CIDRInputStateMachine.valid_cidr_re.fullmatch(b) == None:
                errors += f"  {b}\n"
            blocks.append(b)
        return (blocks, errors)

    # Formats a list of strings according to how terraform wants it.
    def _format_blocks(blocks: List[str]) -> str:
        # Terraform expects lists in the `["item1", "item2", ..., "itemN"]` format:
        # https://developer.hashicorp.com/terraform/language/values/variables#variables-on-the-command-line
        #
        # Notably, single quotes are not valid. Strings in lists formatted in f-strings are wrapped in single
        # quotes so we need to replace them with double quotes.
        return f"{blocks}".replace("'", '"')

    # Returns the final CIDR allow-list.
    def cidrs(self) -> CIDRList:
        if self._state == self.State.DONE:
            return self._cidrs
        else:
            return ""
