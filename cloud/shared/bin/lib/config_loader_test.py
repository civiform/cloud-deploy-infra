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
    Variable, import_mock_env_var_docs_parser,
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
            data = {"object": {"sha": "0123456789"}}
            response._content = json.dumps(data).encode()

        # mock out the case when the version number is not available and the request fails
        else:
            response.status_code = 404
            data = {"message": "no json found"}
            response._content = json.dumps(data).encode()

        return response

    def mocked_get_commit_sha_for_tag(tag_commit_sha):
        if tag_commit_sha == "0123456789":
            return "abcdef"

    @patch('requests.get', side_effect=mocked_get)
    @patch('cloud.shared.bin.lib.config_loader.ConfigLoader._get_commit_sha_for_tag', side_effect=mocked_get_commit_sha_for_tag)
    def test_get_commit_hash_for_release__latest(self, mocked_get, mocked_get_commit_sha_for_tag):
        config_loader = ConfigLoader()
        commit_sha = config_loader._get_commit_sha_for_release("latest")

        self.assertEqual(commit_sha, "abcdef")

    @patch('requests.get', side_effect=mocked_get)
    @patch('cloud.shared.bin.lib.config_loader.ConfigLoader._get_commit_sha_for_tag', side_effect=mocked_get_commit_sha_for_tag)
    def test_get_commit_hash_for_release__with_tag(self, mocked_get, mocked_get_commit_sha_for_tag):
        config_loader = ConfigLoader()
        commit_sha = config_loader._get_commit_sha_for_release("v1.23.0")

        self.assertEqual(commit_sha, "abcdef")

    @patch('requests.get', side_effect=mocked_get)
    def test_get_commit_hash_for_release__fail_case(self, mocked_get):
        config_loader = ConfigLoader()
        try:
            commit_sha = config_loader._get_commit_sha_for_release("invalid tag")
        except ConfigLoader.VersionNotFoundError as e:
            self.assertEqual(
                """The commit sha for version invalid tag could not be found. Are you using a valid tag such as latest or a valid version number like v1.0.0? 404 - no json found""", e.args[0])

    # add test cases for mini functions i made

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
            "FOO_4": "24"
        }
        civiform_server_env_vars = {}

        # See comments on the specifics we pass correct values for
        civiform_server_env_vars["FOO_0"] = env_var_docs_parser.Variable(
            description='description',
            type='string',  # normal string
            required=False,
            values=None,  # with no specified values
            regex=None,  # or regex to check
            regex_tests=None)
        civiform_server_env_vars["FOO_1"] = env_var_docs_parser.Variable(
            description='description',
            type='bool',  # boolean, needs boolean value
            required=True,  # and required -> has to be present
            values=None,
            regex=None,
            regex_tests=None)
        civiform_server_env_vars["FOO_2"] = env_var_docs_parser.Variable(
            description='description',
            type='string',  # string 
            required=True,
            values="value1, value2",  # with specific values
            regex=None,
            regex_tests=None)
        civiform_server_env_vars["FOO_3"] = env_var_docs_parser.Variable(
            description='description',
            type='string',  # string 
            required=True,
            values=None,
            regex="gr(a|e)y",  # that matches a regex
            regex_tests=None)
        civiform_server_env_vars["FOO_4"] = env_var_docs_parser.Variable(
            description='description',
            type='int',  # int has to be int value
            required=True,
            values=None,
            regex=None,
            regex_tests=None)

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
            "FOO_4": "none_int_string"
        }
        civiform_server_env_vars = {}

        # See comments on the specifics we pass correct values for
        civiform_server_env_vars["FOO_0"] = env_var_docs_parser.Variable(
            description='description',
            type='string',
            required=True,  # Required but missing in values
            values=None,
            regex=None,
            regex_tests=None)
        civiform_server_env_vars["FOO_1"] = env_var_docs_parser.Variable(
            description='description',
            type='bool',  # Boolean, but value is other
            required=True,
            values=None,
            regex=None,
            regex_tests=None)
        civiform_server_env_vars["FOO_2"] = env_var_docs_parser.Variable(
            description='description',
            type='string',  # string 
            required=True,
            values="value1, value2",  # does not stick to specific values
            regex=None,
            regex_tests=None)
        civiform_server_env_vars["FOO_3"] = env_var_docs_parser.Variable(
            description='description',
            type='string',  # string 
            required=True,
            values=None,
            regex="gr(a|e)y",  # does not matche regex
            regex_tests=None)
        civiform_server_env_vars["FOO_4"] = env_var_docs_parser.Variable(
            description='description',
            type='int',  # int has, but is not int value
            required=True,
            values=None,
            regex=None,
            regex_tests=None)

        config_loader = ConfigLoader()
        validation_errors = config_loader._validate_civiform_server_env_vars(
            civiform_server_env_vars, config_fields)
        self.assertEqual(
            [
                "'FOO_0' is required but not set",
                "'FOO_1' is required to be either 'true' or 'false', got none_boolean_string",
                "'FOO_2': 'value3' is not a valid value. Valid values are value1, value2",
                "'FOO_3': 'gry' does not match validation regular expression 'gr(a|e)y'",
                "'FOO_4' is required to be an integer: invalid literal for int() with base 10: 'none_int_string'"
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
                regex_tests=None)
        config_loader._civiform_server_env_var_docs[
            "FOO_1"] = env_var_docs_parser.Variable(
                description='description',
                type='string',
                required=True,
                values=None,
                regex=None,
                regex_tests=None)
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
        config_loader._config_fields = {"CIVIFORM_VERSION": "latest"}

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
                            regex_tests=[])
                }, env_var_docs)

    @patch('urllib.request.urlopen')
    def test_download_env_var_docs(self, mock_urlopen):
        config_loader = ConfigLoader()

        mock_response = io.BytesIO(
            b'{ "MY_VAR": { "description": "A var", "type": "string", "type": "bool"} }'
        )
        mock_urlopen.return_value.__enter__.return_value = mock_response

        expected = '{ "MY_VAR": { "description": "A var", "type": "string", "type": "bool"} }'
        env_var_docs = config_loader._download_env_var_docs("latest")
        self.assertEqual(env_var_docs.getvalue(), expected)

if __name__ == "__main__":
    unittest.main()
