import unittest

from cloud.aws.bin.pgadmin import CIDRInputStateMachine
"""
 Tests for the CIDRInputStateMachine.

 To run the tests: PYTHONPATH="${PYTHONPATH}:${pwd}" python3 cloud/aws/bin/pgadmin_test.py
"""


def ip(ip):
    return lambda: ip


class TestCIDRInputStateMachine(unittest.TestCase):

    def test_detected_ip_prompts_for_accept(self):
        sm = CIDRInputStateMachine(ip("127.0.0.1"))
        sm.next("")

        self.assertEqual(sm.state, sm.State.ACCEPT_LIST)
        self.assertEqual(sm.cidrs, '["127.0.0.1/32"]')

    def test_no_detected_ip_prompts_for_input(self):
        sm = CIDRInputStateMachine(ip(""))
        sm.next("")

        self.assertEqual(sm.state, sm.State.SET_VALIDATE_FORMAT)
        self.assertEqual(sm.cidrs, "")

    def test_accept_list_completes_machine(self):
        sm = CIDRInputStateMachine(ip(""))
        sm.next("")

        sm.next("127.0.0.1/32")
        sm.next("y")

        self.assertEqual(sm.state, sm.State.DONE)
        self.assertEqual(sm.cidrs, '["127.0.0.1/32"]')
        self.assertEqual(sm.next("wait I want to change the list!"), "")
        self.assertEqual(sm.cidrs, '["127.0.0.1/32"]')
        self.assertEqual(sm.next("time for ctrl-c I guess"), "")
        self.assertEqual(sm.cidrs, '["127.0.0.1/32"]')

    def test_not_accept_list_prompts_for_input(self):
        sm = CIDRInputStateMachine(ip(""))
        sm.next("")

        sm.next("127.0.0.1/32")
        sm.next("n")

        self.assertEqual(sm.state, sm.State.SET_VALIDATE_FORMAT)
        self.assertEqual(sm.cidrs, "")

    def test_multiple_blocks_parsed(self):
        sm = CIDRInputStateMachine(ip(""))
        sm.next("")

        sm.next("127.0.0.1/32,  126.0.0.1/31,125.0.0.1/30   ")

        self.assertEqual(sm.state, sm.State.ACCEPT_LIST)
        self.assertEqual(
            sm.cidrs, '["127.0.0.1/32", "126.0.0.1/31", "125.0.0.1/30"]')

    def test_all_invalid_blocks(self):
        sm = CIDRInputStateMachine(ip(""))
        sm.next("")

        sm.next("127.0.0.1,  126.0.0.1/33,125.0.0.1/-1   ")

        self.assertEqual(sm.state, sm.State.SET_VALIDATE_FORMAT)
        self.assertEqual(sm.cidrs, "")

    def test_some_invalid_blocks(self):
        sm = CIDRInputStateMachine(ip(""))
        sm.next("")

        sm.next("127.0.0.1/32,  126.0.0.1/33,125.0.0.1/-1   ")

        self.assertEqual(sm.state, sm.State.SET_VALIDATE_FORMAT)
        self.assertEqual(sm.cidrs, "")


if __name__ == "__main__":
    unittest.main()
