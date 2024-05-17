import http.client
import importlib
import io
import os
import subprocess
import sys
import typing
import unittest
import requests
import json
import unittest.mock
from unittest.mock import MagicMock, patch
from urllib.request import urlopen

from cloud.shared.bin.lib.config_loader import (
    CIVIFORM_SERVER_VARIABLES_KEY, ConfigLoader)
from cloud.shared.bin.lib.mock_env_var_docs_parser import (
    Variable, Mode, import_mock_env_var_docs_parser,
    install_mock_env_var_docs_package)
"""
Tests for the ConfigLoader, calls the I/O methods to match the actual
experience of running the class.

To run the tests: PYTHONPATH="${PYTHONPATH}:${pwd}" python3 cloud/shared/bin/lib/config_loader_test.py
"""


class TestConfigLoader(unittest.TestCase):

    def test_validate_config_for_not_including_variable_required__in_infra_variable_definition(
            self):
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

        config_fields = {"FOO": "test"}

        config_loader = ConfigLoader()
        config_loader._config_fields = config_fields
        config_loader._infra_variable_definitions = defs

        self.assertEqual(
            config_loader.validate_config(), ["'Bar' is required but not set"])

    def test_validate_config_for_incorrect_enum__in_infra_variable(self):
        defs = {
            "FOO":
                {
                    "required": True,
                    "secret": False,
                    "type": "enum",
                    "values": ["abc", "def"],
                },
        }
        config_fields = {"FOO": "test"}

        config_loader = ConfigLoader()
        config_loader._config_fields = config_fields
        config_loader._infra_variable_definitions = defs

        self.assertEqual(
            config_loader.validate_config(), [
                "'FOO': 'test' is not a valid enum value. Valid values are ['abc', 'def']"
            ])

    def test_validate_config_for_correct_enums__in_infra_variable(self):
        defs = {
            "FOO":
                {
                    "required": True,
                    "secret": False,
                    "type": "enum",
                    "values": ["abc"],
                },
        }
        config_fields = {"FOO": "abc"}

        config_loader = ConfigLoader()
        config_loader._config_fields = config_fields
        config_loader._infra_variable_definitions = defs

        self.assertEqual(config_loader.validate_config(), [])

    def test_validate_config_for_empty_enum__in_infra_variable(self):
        defs = {
            "FOO":
                {
                    "required": True,
                    "secret": False,
                    "type": "enum",
                    "values": ["abc"],
                },
        }
        config_fields = {"FOO": ""}

        config_loader = ConfigLoader()
        config_loader._config_fields = config_fields
        config_loader._infra_variable_definitions = defs

        self.assertEqual(
            config_loader.validate_config(),
            ["'FOO': '' is not a valid enum value. Valid values are ['abc']"])

    def test_value_regex__in_infra_variable_definition(self):
        defs = {
            "FOO":
                {
                    "required": True,
                    "secret": False,
                    "type": "string",
                    "value_regex": "[a-z]+",
                    "value_regex_error_message": "some message"
                },
        }
        config_fields = {"FOO": "somenumbers123"}

        config_loader = ConfigLoader()
        config_loader._config_fields = config_fields
        config_loader._infra_variable_definitions = defs

        self.assertEqual(
            config_loader.validate_config(),
            ["'FOO': 'somenumbers123' not valid: some message"])

    def test_value_regex_ignored_for_not_required_and_not_provided__in_infra_variable_definitions(
            self):
        defs = {
            "FOO":
                {
                    "required": False,
                    "secret": False,
                    "type": "string",
                    "value_regex": "[a-z]+",
                    "value_regex_error_message": "some message"
                },
        }
        config_fields = {}

        config_loader = ConfigLoader()
        config_loader._config_fields = config_fields
        config_loader._infra_variable_definitions = defs

        self.assertEqual(config_loader.validate_config(), [])

    def mocked_fetch_json_val(url, field_one, field_two=None):
        data = {}
        # mock out getting the sha if a snapshot tag is passed in
        if url == "https://api.github.com/repos/civiform/civiform/commits/abc":
            data = {"sha": "abcdef"}
        # mock out getting the tag_url for the version number v1.23.0
        elif url == "https://api.github.com/repos/civiform/civiform/git/refs/tags/v1.23.0":
            data = {"object": {"url": "fake_tag_url"}}
        # mock out getting the sha from the tag_url for version number v1.23.0
        elif url == "fake_tag_url":
            data = {"object": {"sha": "abc123"}}
        else:
            return None
        return data[field_one] if field_two is None else data[field_one][
            field_two]

    @patch(
        'cloud.shared.bin.lib.config_loader.ConfigLoader._fetch_json_val',
        side_effect=mocked_fetch_json_val)
    def test_get_commit_hash_for_tag__snapshot(self, mocked_fetch_json_val):
        config_loader = ConfigLoader()
        commit_sha = config_loader._get_commit_sha_for_tag("SNAPSHOT-abc-12345")

        self.assertEqual(commit_sha, "abcdef")

    @patch(
        'cloud.shared.bin.lib.config_loader.ConfigLoader._fetch_json_val',
        side_effect=mocked_fetch_json_val)
    def test_get_commit_hash_for_tag__version(self, mocked_fetch_json_val):
        config_loader = ConfigLoader()
        commit_sha = config_loader._get_commit_sha_for_tag("v1.23.0")

        self.assertEqual(commit_sha, "abc123")

    @patch(
        'cloud.shared.bin.lib.config_loader.ConfigLoader._fetch_json_val',
        side_effect=mocked_fetch_json_val)
    def test_get_commit_hash_for_tag__fail_case(self, mocked_fetch_json_val):
        config_loader = ConfigLoader()
        commit_sha = config_loader._get_commit_sha_for_tag("invalid tag")
        self.assertEqual(commit_sha, None)

    @patch('importlib.import_module')
    def test_validate_correct_values_in_config__for_server_variables(
            self, mock_import_module):
        env_var_docs_parser = import_mock_env_var_docs_parser(
            self, mock_import_module)

        config_fields = {
            "FOO_0": "somenumbers123",
            "FOO_1": "true",
            "FOO_2": "value1",
            "FOO_3": "grey",
            "FOO_4": "24",
            "FOO_5": "writeable_var",
            "ALLOW_ADMIN_WRITEABLE": "true"
        }
        civiform_server_env_vars = {}
        # See comments on the specifics we pass correct values for
        civiform_server_env_vars["FOO_0"] = env_var_docs_parser.Variable(
            description='description',
            type='string',  # normal string
            required=False,
            values=None,  # with no specified values
            regex=None,  # or regex to check
            regex_tests=None,
            mode=Mode.ADMIN_READABLE)
        civiform_server_env_vars["FOO_1"] = env_var_docs_parser.Variable(
            description='description',
            type='bool',  # boolean, needs boolean value
            required=True,  # and required -> has to be present
            values=None,
            regex=None,
            regex_tests=None,
            mode=Mode.ADMIN_READABLE)
        civiform_server_env_vars["FOO_2"] = env_var_docs_parser.Variable(
            description='description',
            type='string',  # string 
            required=True,
            values="value1, value2",  # with specific values
            regex=None,
            regex_tests=None,
            mode=Mode.ADMIN_READABLE)
        civiform_server_env_vars["FOO_3"] = env_var_docs_parser.Variable(
            description='description',
            type='string',  # string 
            required=True,
            values=None,
            regex="gr(a|e)y",  # that matches a regex
            regex_tests=None,
            mode=Mode.ADMIN_READABLE)
        civiform_server_env_vars["FOO_4"] = env_var_docs_parser.Variable(
            description='description',
            type='int',  # int has to be int value
            required=True,
            values=None,
            regex=None,
            regex_tests=None,
            mode=Mode.ADMIN_READABLE)
        civiform_server_env_vars["FOO_5"] = env_var_docs_parser.Variable(
            description='description',
            type='string',
            required=False,
            values=None,
            regex=None,
            regex_tests=None,
            mode=Mode.ADMIN_WRITEABLE
        )  # mode is ADMIN_WRITEABLE but override is set so should be ignored

        config_loader = ConfigLoader()
        validation_errors = config_loader._validate_civiform_server_env_vars(
            civiform_server_env_vars, config_fields)
        self.assertEqual([], validation_errors)

    @patch('importlib.import_module')
    def test_validate_incorrect_values_in_config__for_server_variables(
            self, mock_import_module):
        env_var_docs_parser = import_mock_env_var_docs_parser(
            self, mock_import_module)

        config_fields = {
            "FOO_1": "none_boolean_string",
            "FOO_2": "value3",
            "FOO_3": "gry",
            "FOO_4": "none_int_string",
            "FOO_6": "writeable_var"
        }
        civiform_server_env_vars = {}

        # See comments on the specifics we pass correct values for
        civiform_server_env_vars["FOO_0"] = env_var_docs_parser.Variable(
            description='description',
            type='string',
            required=True,  # Required but missing in values
            values=None,
            regex=None,
            regex_tests=None,
            mode=Mode.ADMIN_READABLE)
        civiform_server_env_vars["FOO_1"] = env_var_docs_parser.Variable(
            description='description',
            type='bool',  # Boolean, but value is other
            required=True,
            values=None,
            regex=None,
            regex_tests=None,
            mode=Mode.ADMIN_READABLE)
        civiform_server_env_vars["FOO_2"] = env_var_docs_parser.Variable(
            description='description',
            type='string',  # string 
            required=True,
            values="value1, value2",  # does not stick to specific values
            regex=None,
            regex_tests=None,
            mode=Mode.ADMIN_READABLE)
        civiform_server_env_vars["FOO_3"] = env_var_docs_parser.Variable(
            description='description',
            type='string',  # string 
            required=True,
            values=None,
            regex="gr(a|e)y",  # does not match regex
            regex_tests=None,
            mode=Mode.ADMIN_READABLE)
        civiform_server_env_vars["FOO_4"] = env_var_docs_parser.Variable(
            description='description',
            type='int',  # int has, but is not int value
            required=True,
            values=None,
            regex=None,
            regex_tests=None,
            mode=Mode.ADMIN_READABLE)
        civiform_server_env_vars["FOO_5"] = env_var_docs_parser.Variable(
            description='description',
            type='string',
            required=
            True,  # required and not set in config but mode is ADMIN_WRITEABLE so should be ignored
            values=None,
            regex=None,
            regex_tests=None,
            mode=Mode.ADMIN_WRITEABLE)
        civiform_server_env_vars["FOO_6"] = env_var_docs_parser.Variable(
            description='description',
            type='string',
            required=False,
            values=None,
            regex=None,
            regex_tests=None,
            mode=Mode.ADMIN_WRITEABLE
        )  # is included in config_fields and mode is ADMIN_WRITEABLE so should throw an error

        config_loader = ConfigLoader()
        validation_errors = config_loader._validate_civiform_server_env_vars(
            civiform_server_env_vars, config_fields)
        self.assertEqual(
            [
                '\x1b[31mFOO_0 is required but not set\x1b[0m',
                '\x1b[31mFOO_1 is required to be either true or false, got none_boolean_string\x1b[0m',
                '\x1b[31mFOO_2: value3 is not a valid value. Valid values are value1, value2\x1b[0m',
                '\x1b[31mFOO_3: gry does not match validation regular expression gr(a|e)y\x1b[0m',
                '\x1b[31mFOO_4 is required to be an integer: invalid literal for int() with base 10: none_int_string\x1b[0m',
                '\x1b[31mFOO_6 is editable via the admin settings panel and should not be set in the deploy config. Please remove it from your config file and try again. Set ALLOW_ADMIN_WRITEABLE=true in your config file to ignore this warning (use with caution).\x1b[0m'
            ], validation_errors)

    @patch('importlib.import_module')
    def test_get_terraform_variables(self, mock_import_module):
        env_var_docs_parser = import_mock_env_var_docs_parser(
            self, mock_import_module)
        config_loader = ConfigLoader()

        defs = {
            "FOO_0":
                {
                    "required": True,
                    "secret": False,
                    "tfvar": False,
                    "type": "string"
                },
            "FOO_1":
                {
                    "required": True,
                    "secret": False,
                    "tfvar": True,
                    "type": "string"
                },
        }
        config_loader._infra_variable_definitions = defs

        config_loader._civiform_server_env_var_docs = {}
        config_loader._civiform_server_env_var_docs[
            "FOO_0"] = env_var_docs_parser.Variable(
                description='description',
                type='index-list',
                required=True,
                values=None,
                regex=None,
                regex_tests=None,
                mode=Mode.ADMIN_READABLE)
        config_loader._civiform_server_env_var_docs[
            "FOO_1"] = env_var_docs_parser.Variable(
                description='description',
                type='string',
                required=True,
                values=None,
                regex=None,
                regex_tests=None,
                mode=Mode.ADMIN_READABLE)
        config_loader._config_fields = config_fields = {
            "FOO_0": "item0, item1, item2",
            "FOO_1": "normal string"
        }

        terraform_vars = config_loader.get_terraform_variables()
        self.assertEqual(2, len(terraform_vars))
        self.assertEqual(terraform_vars["FOO_1"], "normal string")

        server_vars = terraform_vars[CIVIFORM_SERVER_VARIABLES_KEY]
        self.assertEqual(server_vars["FOO_1"], "normal string")
        self.assertEqual(server_vars["FOO_0.0"], "item0")
        self.assertEqual(server_vars["FOO_0.1"], "item1")
        self.assertEqual(server_vars["FOO_0.2"], "item2")

    def test_load_civiform_server_env_vars_empty_if_env_var_docs_package_not_present(
            self):
        # Skip mocking out the presence of the env var docs package (see other tests)
        config_loader = ConfigLoader()
        server_vars = config_loader._load_civiform_server_env_vars()
        # Because the package is not present, no server variables were loaded
        self.assertEqual(server_vars, {})

    @patch('importlib.import_module')
    def test_load_civiform_server_env_vars(self, mock_import_module):
        config_loader = ConfigLoader()
        config_loader._config_fields = {"CIVIFORM_VERSION": "v1.23.0"}
        os.environ['TF_VAR_image_tag'] = "v1.23.0"

        # Instead of downloading the env_var_docs from github, mock out the download call
        def mock_download_env_var_docs(civiform_version: str):
            env_var_docs = io.StringIO(
                '{ "MY_VAR": { "description": "A var", "type": "string", "type": "bool"} }'
            )
            return env_var_docs

        with patch(
                'cloud.shared.bin.lib.config_loader.ConfigLoader._download_env_var_docs',
                side_effect=mock_download_env_var_docs):
            install_mock_env_var_docs_package(self, mock_import_module)
            env_var_docs = config_loader._load_civiform_server_env_vars()
            # Assert that the python module that enables the variable auto generation is downloaded
            mock_import_module.assert_called_with('env_var_docs.parser')
            self.assertEqual(
                {
                    'test-variable-node':
                        Variable(
                            description='description',
                            type='string',
                            required=False,
                            values=[],
                            regex='',
                            regex_tests=[],
                            mode=Mode.ADMIN_READABLE)
                }, env_var_docs)

    @patch('urllib.request.urlopen')
    def test_download_env_var_docs(self, mock_urlopen):
        config_loader = ConfigLoader()

        mock_response = io.BytesIO(
            b'{ "MY_VAR": { "description": "A var", "type": "string", "type": "bool"} }'
        )
        mock_urlopen.return_value.__enter__.return_value = mock_response

        expected = '{ "MY_VAR": { "description": "A var", "type": "string", "type": "bool"} }'
        env_var_docs = config_loader._download_env_var_docs("v1.23.0")
        self.assertEqual(env_var_docs.getvalue(), expected)


if __name__ == "__main__":
    unittest.main()
