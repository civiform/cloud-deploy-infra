import unittest
import json
import os

from cloud.shared.bin.lib.variable_definition_loader import VariableDefinitionLoader

class TestVariableDefinitionLoader(unittest.TestCase):
    __json_file_path_name = "./test_variable_definition_file.json"

    __valid_variable_defs = {
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
    
    __variable_defs_with_duplicate = {
        "Pen": {
            "required": True,
            "secret": False,
            "type": "string"
        },
        "Bar": {
            "required": True,
            "secret": False,
            "type": "string"
        },
        "Baf": {
            "required": False,
            "secret": False,
            "type": "string"
        },
    }

    def test_validate_all_variable_definitions(self):        
        varDefLoader = VariableDefinitionLoader()
        self._write_json_file(self.__valid_variable_defs, self.__json_file_path_name)
        varDefLoader.load_definition_file(self.__json_file_path_name)
        vars = varDefLoader.get_variable_definitions() 
        self.assertEqual(vars, self.__valid_variable_defs)

    # def test_duplicate_var_throws_error(self):
        varDefLoader = VariableDefinitionLoader()
        self._write_json_file(self.__valid_variable_defs, self.__json_file_path_name)
        try:
            varDefLoader.load_definition_file(self.__json_file_path_name)
        except RuntimeError as e:
            self.assertEqual(e.args[0], "Duplicate variable name: FOO at ./test_variable_definition_file.json")
        
    
    def _write_json_file(self, json_content, filepath: str):        
        defs_string = json.dumps(json_content)
        with open(filepath, "w") as var_defs_file:
            var_defs_file.write(defs_string)

    def tearDown(self):

        os.remove("./test_variable_definition_file.json")

          

if __name__ == '__main__':
    unittest.main()
