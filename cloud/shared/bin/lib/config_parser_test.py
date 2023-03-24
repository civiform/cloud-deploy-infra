import unittest
import tempfile
import warnings

from cloud.shared.bin.lib.config_parser import ConfigParser
"""
 Tests for the ConfigParser

 To run the tests: PYTHONPATH="${PYTHONPATH}:${pwd}" python3 cloud/shared/bin/lib/config_parser_test.py
"""


class TestConfigParser(unittest.TestCase):

    __valid_config_string = """
# Comment line with random symbols ':"#%()
# More comments
export ENV_VAR="env-var"

# Another comment line with random symbols ':"
# More comments
export SECOND_ENV_VAR="env-var-2#2" #inline comment
"""
    __random_extra_line = "random extra line"

    __env_var_with_hash = "export ENV_VAR_3 = 23  # inline comment"

    __expected_error_message = f"""Error, Invalid line found:
{__random_extra_line}
The config file should contain only exported system variables in the format: export VARIABLE_NAME=variable_value"""

    __expected_warning = f"""'#' found in env variable definition: 'export ENV_VAR_3 = 23  # inline comment'. 
Inline comments are not allowed and all characters, including '#' will be considered part of the value."""

    def test_parse_valid_config(self):
        config = self.__parse_config_from_string(self.__valid_config_string)
        self.assertEqual(
            {
                'ENV_VAR': 'env-var',
                'SECOND_ENV_VAR': 'env-var-2#2'
            }, config)

    def test_parse_config_with_invalid_extra_line_throws_error(self):
        invalid_config_string = self.__valid_config_string + self.__random_extra_line
        try:
            config = self.__parse_config_from_string(invalid_config_string)
        except ValueError as error:
            self.assertEqual(self.__expected_error_message, error.args[0])

    def test_strip_quotes(self):
        config_parser = ConfigParser()
        config_parser.strip_quotes("\"dingle dongle")
        config_parser.strip_quotes("\"dingle dongle\"")

    def __parse_config_from_string(self, config_file_content):
        with tempfile.NamedTemporaryFile(mode='w') as config_file:
            with open(config_file.name, "w") as f:
                f.write(config_file_content)
            config_parser = ConfigParser()
            return config_parser.parse_config(config_file.name)


if __name__ == "__main__":
    unittest.main()
