import re
import urllib.error
import urllib.request

from enum import Enum
from typing import List

UserPrompt = str
UserInput = str
CIDRList = str


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

    def detect_public_ip(self) -> str:
        try:
            with urllib.request.urlopen("https://checkip.amazonaws.com",
                                        timeout=3) as response:
                # response contains a newline
                return response.read().decode("ascii").strip()
        except:
            return ""

    def __init__(self):
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
            ip = self.detect_public_ip()
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
