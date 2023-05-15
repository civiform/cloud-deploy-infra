import unittest
import requests
import json
from unittest.mock import patch, MagicMock

from cloud.shared.bin.lib.config_loader import ConfigLoader
"""
 Tests for the ConfigLoader, calls the I/O methods to match the actual
 experience of running the class.

 To run the tests: PYTHONPATH="${PYTHONPATH}:${pwd}" python3 cloud/shared/bin/lib/config_loader_test.py
"""


class TestConfigLoader(unittest.TestCase):

    def test_validate_config_for_not_including_required(self):
        defs = {
            "FOO": {
                "required": True,
                "secret": False,
                "type": "string"
            },
            "Bar": {
                "required": True,
                "secret": False,
                "type": "string"
            },
            "Bat": {
                "required": False,
                "secret": False,
                "type": "string"
            },
        }

        configs = {"FOO": "test"}

        config_loader = ConfigLoader()
        config_loader.variable_definitions = defs
        config_loader.configs = configs

        self.assertEqual(
            config_loader.validate_config(),
            ["[Bar] required, but not provided"])

    def test_validate_config_for_incorrect_enums(self):
        defs = {
            "FOO":
                {
                    "required": True,
                    "secret": False,
                    "type": "enum",
                    "values": ["abc", "def"],
                },
        }
        configs = {"FOO": "test"}

        config_loader = ConfigLoader()
        config_loader.variable_definitions = defs
        config_loader.configs = configs

        self.assertEqual(
            config_loader.validate_config(), [
                "[FOO] 'test' is not a supported enum value. Want a value in [abc, def]"
            ])

    def test_validate_config_for_correct_enums(self):
        defs = {
            "FOO":
                {
                    "required": True,
                    "secret": False,
                    "type": "enum",
                    "values": ["abc"],
                },
        }
        configs = {"FOO": "abc"}
        config_loader = ConfigLoader()
        config_loader.variable_definitions = defs
        config_loader.configs = configs

        self.assertEqual(config_loader.validate_config(), [])

    def test_validate_config_for_empty_enum(self):
        defs = {
            "FOO":
                {
                    "required": True,
                    "secret": False,
                    "type": "enum",
                    "values": ["abc"],
                },
        }

        configs = {"FOO": ""}
        config_loader = ConfigLoader()
        config_loader.variable_definitions = defs
        config_loader.configs = configs

        self.assertEqual(
            config_loader.validate_config(),
            ["[FOO] '' is not a supported enum value. Want a value in [abc]"])

    def test_value_regex(self):
        config_loader = ConfigLoader()
        config_loader.variable_definitions = {
            "FOO":
                {
                    "required": True,
                    "secret": False,
                    "type": "string",
                    "value_regex": "[a-z]+",
                    "value_regex_error_message": "some message"
                },
        }

        config_loader.configs = {"FOO": "somenumbers123"}
        self.assertEqual(
            config_loader.validate_config(),
            ['[FOO] \'somenumbers123\' not valid: some message'])

    def test_value_regex_ignored_for_not_required_and_not_provided(self):
        config_loader = ConfigLoader()
        config_loader.variable_definitions = {
            "FOO":
                {
                    "required": False,
                    "secret": False,
                    "type": "string",
                    "value_regex": "[a-z]+",
                    "value_regex_error_message": "some message"
                },
        }

        config_loader.configs = {}
        self.assertEqual(config_loader.validate_config(), [])

    def mocked_get(url):
        response = requests.Response()
        response.headers["Content-type"] = "application/json"

        # mock out getting the version number that matches "latest"
        if url == "https://api.github.com/repos/civiform/civiform/releases/latest":
            response.status_code = 200
            data_1 = {"tag_name": "v1.23.0"}
            response._content = json.dumps(data_1).encode()

        # mock out getting the sha for for the version number v1.23.0
        elif url == "https://api.github.com/repos/civiform/civiform/git/refs/tags/v1.23.0":
            response.status_code = 200
            data = {"object": {"sha": "0123456789abcdef"}}
            response._content = json.dumps(data).encode()

        # mock out the case when the version number is not available and the request fails
        else:
            response.status_code = 404
            data = {"message": "no json found"}
            response._content = json.dumps(data).encode()

        return response

    @patch('requests.get', side_effect=mocked_get)
    def test_get_commit_hash_for_release__success_case(self, mocked_get):
        config_loader = ConfigLoader()
        commit_sha = config_loader.get_commit_sha_for_release("latest")

        #mock_requests.assert_called_with("https://api.github.com/repos/civiform/civiform/git/refs/tags/V1.0.0")
        self.assertEqual(commit_sha, "0123456789abcdef")

    @patch('requests.get', side_effect=mocked_get)
    def test_get_commit_hash_for_release__fail_case(self, mocked_requests):
        config_loader = ConfigLoader()
        try:
            commit_sha = config_loader.get_commit_sha_for_release("invalid tag")
        except ConfigLoader.VersionNotFoundError as e:
            self.assertEqual(
                """The commit sha for version invalid tag could not be found. Are you using a valid tag such as latest or a valid version number like v1.0.0?
 404 - no json found""", e.args[0])


if __name__ == "__main__":
    unittest.main()
