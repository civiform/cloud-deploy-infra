import unittest

from dataclasses import dataclass
from typing import List

from cloud.aws.bin.pgadmin import CIDRInputStateMachine
"""
 Tests for the CIDRInputStateMachine.

 To run the tests: PYTHONPATH="${PYTHONPATH}:${pwd}" python3 cloud/aws/bin/pgadmin_test.py
"""


def ip(ip):
    return lambda: ip


class TestCIDRInputStateMachine(unittest.TestCase):

    def test_first_state_is_detect_ip(self):
        sm = CIDRInputStateMachine(ip("127.0.0.1"))

        self.assertEqual(sm._state, sm.State.DETECT_IP)
        self.assertEqual(sm._ip, "")
        self.assertEqual(sm._cidrs, "")

    def test_first_state_is_detect_ip_even_if_detect_ip_disabled(self):
        sm = CIDRInputStateMachine(ip(""))

        self.assertEqual(sm._state, sm.State.DETECT_IP)
        self.assertEqual(sm._ip, "")
        self.assertEqual(sm._cidrs, "")

    def test_detected_ip_prompts_to_use_ip(self):
        sm = CIDRInputStateMachine(ip("127.0.0.1"))
        sm.next("")

        self.assertEqual(sm._state, sm.State.ADD_DETECTED_IP)
        self.assertEqual(sm._ip, "127.0.0.1")
        self.assertEqual(sm._cidrs, "")

    def test_accepting_ip_prompts_for_additional_blocks(self):
        sm = CIDRInputStateMachine(ip("127.0.0.1"))
        sm.next("")

        sm.next("y")

        self.assertEqual(sm._state, sm.State.APPEND_VALIDATE_FORMAT)
        self.assertEqual(sm._ip, "127.0.0.1")
        self.assertEqual(sm._cidrs, "")

    def test_accepting_ip_appends_it_to_list(self):
        sm = CIDRInputStateMachine(ip("127.0.0.1"))
        sm.next("")

        sm.next("y")
        sm.next("128.0.0.1/32")
        sm.next("y")

        self.assertEqual(sm._state, sm.State.DONE)
        self.assertEqual(sm._ip, "127.0.0.1")
        self.assertEqual(sm._cidrs, '["127.0.0.1/32", "128.0.0.1/32"]')

    def test_using_ip_then_not_accepting_list_removes_ip(self):
        sm = CIDRInputStateMachine(ip("127.0.0.1"))
        sm.next("")

        sm.next("y")
        sm.next("128.0.0.1/32")
        sm.next("n")

        self.assertEqual(sm._state, sm.State.SET_VALIDATE_FORMAT)
        self.assertEqual(sm._ip, "")
        self.assertEqual(sm._cidrs, "")

    def test_using_ip_then_not_accepting_list_then_inputting_list_does_not_have_ip(
            self):
        sm = CIDRInputStateMachine(ip("127.0.0.1"))
        sm.next("")

        sm.next("y")
        sm.next("128.0.0.2/32")
        sm.next("n")
        sm.next("128.0.0.2/32")
        sm.next("y")

        self.assertEqual(sm._state, sm.State.DONE)
        self.assertEqual(sm._ip, "")
        self.assertEqual(sm._cidrs, '["128.0.0.2/32"]')

    def test_no_detected_ip_prompts_for_input(self):
        sm = CIDRInputStateMachine(ip(""))
        sm.next("")

        self.assertEqual(sm._state, sm.State.SET_VALIDATE_FORMAT)
        self.assertEqual(sm._ip, "")
        self.assertEqual(sm._cidrs, "")

    def test_accept_list_completes_machine(self):
        sm = CIDRInputStateMachine(ip(""))
        sm.next("")

        sm.next("127.0.0.1/32")
        got = sm.next("y")

        self.assertEqual(got, "")
        self.assertEqual(sm._state, sm.State.DONE)
        self.assertEqual(sm.cidrs(), '["127.0.0.1/32"]')

        self.assertEqual(sm.next("wait I want to change the list!"), "")
        self.assertEqual(sm._cidrs, '["127.0.0.1/32"]')
        self.assertEqual(sm.cidrs(), '["127.0.0.1/32"]')

        self.assertEqual(sm.next("time for ctrl-c I guess"), "")
        self.assertEqual(sm._cidrs, '["127.0.0.1/32"]')
        self.assertEqual(sm.cidrs(), '["127.0.0.1/32"]')

    def test_not_accept_list_prompts_for_input(self):
        sm = CIDRInputStateMachine(ip(""))
        sm.next("")

        sm.next("127.0.0.1/32")
        sm.next("n")

        self.assertEqual(sm._state, sm.State.SET_VALIDATE_FORMAT)
        self.assertEqual(sm._cidrs, "")

    def test_multiple_blocks_parsed(self):
        sm = CIDRInputStateMachine(ip(""))
        sm.next("")

        sm.next("127.0.0.1/32,  126.0.0.1/31,125.0.0.1/30   ")

        self.assertEqual(sm._state, sm.State.ACCEPT_LIST)
        self.assertEqual(
            sm._cidrs, '["127.0.0.1/32", "126.0.0.1/31", "125.0.0.1/30"]')

    def test_all_invalid_blocks(self):
        sm = CIDRInputStateMachine(ip(""))
        sm.next("")

        sm.next("127.0.0.1,  126.0.0.1/33,125.0.0.1/-1   ")

        self.assertEqual(sm._state, sm.State.SET_VALIDATE_FORMAT)
        self.assertEqual(sm._cidrs, "")

    def test_some_invalid_blocks(self):
        sm = CIDRInputStateMachine(ip(""))
        sm.next("")

        sm.next("127.0.0.1/32,  126.0.0.1/33,125.0.0.1/-1   ")

        self.assertEqual(sm._state, sm.State.SET_VALIDATE_FORMAT)
        self.assertEqual(sm._cidrs, "")

    def test_empty_cidr_list_not_valid(self):
        sm = CIDRInputStateMachine(ip(""))
        sm.next("")

        sm.next("")

        self.assertEqual(sm._state, sm.State.SET_VALIDATE_FORMAT)
        self.assertEqual(sm._cidrs, "")

    def test_cidrs_returns_empty_string_until_done(self):
        sm = CIDRInputStateMachine(ip(""))

        sm.next("")
        self.assertEqual(sm._state, sm.State.SET_VALIDATE_FORMAT)
        self.assertEqual(sm.cidrs(), "")

        sm.next("127.0.0.1/32")
        self.assertEqual(sm._state, sm.State.ACCEPT_LIST)
        self.assertEqual(sm.cidrs(), "")

        sm.next("n")
        self.assertEqual(sm._state, sm.State.SET_VALIDATE_FORMAT)
        self.assertEqual(sm.cidrs(), "")

        sm.next("127.0.0.1/32")
        self.assertEqual(sm._state, sm.State.ACCEPT_LIST)
        self.assertEqual(sm.cidrs(), "")

        sm.next("y")
        self.assertEqual(sm._state, sm.State.DONE)
        self.assertEqual(sm.cidrs(), '["127.0.0.1/32"]')

    def test_parse_blocks(self):

        @dataclass
        class TestCase:
            input: str
            want: List[str]

        tests = [
            TestCase(
                input="",
                want=[],
            ),
            TestCase(
                input="127.0.0.1/32",
                want=["127.0.0.1/32"],
            ),
            TestCase(
                input=",127.0.0.1/32",
                want=["127.0.0.1/32"],
            ),
            TestCase(
                input=",127.0.0.1/32,",
                want=["127.0.0.1/32"],
            ),
            TestCase(
                input="127.0.0.1/32,127.0.0.2/32",
                want=["127.0.0.1/32", "127.0.0.2/32"],
            ),
            TestCase(
                input="     127.0.0.1/32              ,127.0.0.2/32,",
                want=["127.0.0.1/32", "127.0.0.2/32"],
            ),
        ]
        for test in tests:
            got, got_errors = CIDRInputStateMachine._parse_blocks(test.input)
            self.assertEqual(
                got_errors,
                "",
                msg=
                f"CIDRInputStateMachine._parse_blocks({test.input}) returned errors {got_errors}, expected none"
            )
            self.assertListEqual(
                got,
                test.want,
                msg=
                f"CIDRInputStateMachine._parse_blocks({test.input}) returned {got}, expected {test.want}"
            )

    def test_parse_blocks_errors(self):

        @dataclass
        class TestCase:
            input: str
            want: str

        tests = [
            TestCase(
                input="this_is_an_ip",
                want="  this_is_an_ip\n",
            ),
            TestCase(
                input="256.0.0.1",
                want="  256.0.0.1\n",
            ),
            TestCase(
                input="127.0.0.1/33",
                want="  127.0.0.1/33\n",
            ),
            TestCase(
                input="256.0.0.1,127.0.0.1/33",
                want="  256.0.0.1\n  127.0.0.1/33\n",
            ),
        ]
        for test in tests:
            _, got = CIDRInputStateMachine._parse_blocks(test.input)
            self.assertEqual(
                got,
                test.want,
                msg=
                f"CIDRInputStateMachine._parse_blocks({test.input}) returned errors {got}, expected {test.want}"
            )

    def test_format_blocks(self):

        @dataclass
        class TestCase:
            input: List[str]
            want: str

        tests = [
            TestCase(input=["127.0.0.1/32"], want='["127.0.0.1/32"]'),
            TestCase(
                input=["127.0.0.1/32", "127.0.0.2/32"],
                want='["127.0.0.1/32", "127.0.0.2/32"]')
        ]
        for test in tests:
            got = CIDRInputStateMachine._format_blocks(test.input)
            self.assertEqual(
                got,
                test.want,
                msg=
                f"CIDRInputStateMachine._format_blocks({test.input}) returned {got}, expected {test.want}"
            )


if __name__ == "__main__":
    unittest.main()
