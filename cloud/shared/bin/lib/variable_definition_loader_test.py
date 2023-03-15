import unittest
import json
import os
import tempfile

from cloud.shared.bin.lib.variable_definition_loader import load_variables
"""
Tests the loading of configuration variables from a json file.

To run the tests from the root direcory of the deploy-infra repostory run:
   PYTHONPATH="${PYTHONPATH}:${pwd}" 
   python3 cloud/shared/bin/lib/variable_definition_loader_test.py
"""


class TestLoadVariables(unittest.TestCase):

    __valid_variable_defs = {
        "BING": {
            "required": True,
            "secret": False,
            "type": "string"
        },
        "BONG": {
            "required": True,
            "secret": False,
            "type": "string"
        },
        "BOB": {
            "required": False,
            "secret": False,
            "type": "string"
        },
    }

    def test_load_valid_variable_definitions(self):
        with tempfile.NamedTemporaryFile(mode='w') as f:
            self._write_json_file(self.__valid_variable_defs, f.name)
            vars = load_variables(f.name)
            self.assertEqual(vars, self.__valid_variable_defs)

    def _write_json_file(self, json_content, filepath: str):
        defs_string = json.dumps(json_content)
        with open(filepath, "w") as var_defs_file:
            var_defs_file.write(defs_string)


if __name__ == '__main__':
    unittest.main()
