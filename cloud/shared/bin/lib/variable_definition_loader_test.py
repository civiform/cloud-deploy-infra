import unittest
import json
import os

from cloud.shared.bin.lib.variable_definition_loader import VariableDefinitionLoader
"""
 Tests for the VariableDefinitionLoader. Tests the loading of configuration
 variables from a json file.

 To run the tests from the root direcory of the deploy-infra repostory run:
    PYTHONPATH="${PYTHONPATH}:${pwd}" 
    python3 cloud/shared/bin/lib/variable_definition_loader_test.py
"""

class TestVariableDefinitionLoader(unittest.TestCase):

    __json_file_path_name = "./test_variable_definition_file.json"

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
    
    __variable_defs_with_duplicate = {
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
        "BONG": {
            "required": False,
            "secret": False,
            "type": "string"
        },
    }


    def test_load_valid_variable_definitions(self):   
        self.__json_file_path_name = "./valid_vars_testfile.json"
        varDefLoader = VariableDefinitionLoader({})
        self._write_json_file(self.__valid_variable_defs, self.__json_file_path_name)
        varDefLoader.load_definition_file(self.__json_file_path_name)
        vars = varDefLoader.get_variable_definitions()
        self.assertEqual(vars, self.__valid_variable_defs)

    def test_duplicate_variable_throws_error(self):
        self.__json_file_path_name = "./invalid_vars_testfile.json"
        varDefLoader = VariableDefinitionLoader({})
        self._write_json_file(self.__variable_defs_with_duplicate, self.__json_file_path_name)
        try:
            varDefLoader.load_definition_file(self.__json_file_path_name)
        except RuntimeError as e:
            self.assertEqual(e.args[0], "Duplicate variable name: BONG at ./test_variable_definition_file.json") 

     
    
    def _write_json_file(self, json_content, filepath: str):        
        defs_string = json.dumps(json_content)
        with open(filepath, "w") as var_defs_file:
            var_defs_file.write(defs_string)

    def tearDown(self):
        os.remove(self.__json_file_path_name)

if __name__ == '__main__':
    unittest.main()
