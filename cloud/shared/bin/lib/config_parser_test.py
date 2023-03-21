import unittest
import tempfile

from cloud.shared.bin.lib.config_parser import ConfigParser
"""
 Tests for the ConfigParser

 To run the tests: PYTHONPATH="${PYTHONPATH}:${pwd}" python3 cloud/shared/bin/lib/config_parser_test.py
"""

class TestConfigLoader(unittest.TestCase):

    __valid_config_string = """
# Comment line with random symbols ':"
# More comments
export ENV_VAR="env-var"

# Another comment line with random symbols ':"
# More comments
export SECOND_ENV_VAR="env-var-2"
"""
    __randow_extra_line = "this should not parse(not a comment or export)"

    __invalid_config_string_1 = """
    """

    def test_parse_valid_config(self):
        with tempfile.NamedTemporaryFile(mode='w') as config_file:
            config_file.write(self.__valid_config_string)
            config_parser = ConfigParser()
            config = config_parser.parse_config(config_file.name)
            self.assertEqual({}, config)
            self.assertEqual(False, True)

    def test_parse_valid_config(self):
        with tempfile.NamedTemporaryFile(mode='w') as config_file:
            config_file.write(self.__valid_config_string)
            config_file.write(self.__randow_extra_line)
            config_parser = ConfigParser()
            config = config_parser.parse_config(config_file.name)
            self.assertEqual({}, config)

    def test_strip_quotes(self):
        config_parser = ConfigParser()
        config_parser.strip_quotes("\"dingle dongle")
        config_parser.strip_quotes("\"dingle dongle\"")

if __name__ == "__main__":
    unittest.main()
