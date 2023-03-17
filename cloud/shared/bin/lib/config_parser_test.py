import unittest

from cloud.shared.bin.lib.config_parser import ConfigParser
"""
 Tests for the ConfigParser

 To run the tests: PYTHONPATH="${PYTHONPATH}:${pwd}" python3 cloud/shared/bin/lib/config_parser_test.py
"""


class TestConfigLoader(unittest.TestCase):

    def test_validate_config_for_not_including_required(self):
       config_parser = ConfigParser()
       config_parser.parse_config("/Users/jhummel/CiviForm/cloud-deploy-infra/civiform_config.sh")

    def test_strip_quotes(self):
        config_parser = ConfigParser()
        config_parser.strip_quotes("\"dingle dongle")
        config_parser.strip_quotes("\"dingle dongle\"")

if __name__ == "__main__":
    unittest.main()
