import unittest
import io
import sys
import unittest.mock
import importlib
import subprocess
import os

from cloud.shared.bin.lib.config_loader import ConfigLoader
"""
Tests for the ConfigLoader, calls the I/O methods to match the actual
experience of running the class.

To run the tests: PYTHONPATH="${PYTHONPATH}:${pwd}" python3 cloud/shared/bin/lib/config_loader_test.py
"""


class TestConfigLoader(unittest.TestCase):

    def test_validate_config_for_not_including_variable_required__in_infra_variable_definition(self):
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
        
    #def test_just_setup():
        
        # script_path = "path/to/script"
        # requirements_file = "/path/to/requirements.txt"

        # os.system(f'source {script_path} && initialize_python_env {requirements_file}')


        # script_path = "/Users/jhummel/Civiform/cloud-deploy-infra/cloud/shared/bin/python_dependencies"
        # requirements_file = "/Users/jhummel/Civiform/cloud-deploy-infra/cloud/requirements.txt"

        # output_file =os.popen(f'source {script_path}')
        # output = output_file.read()
        # print(output)

        # os.system(f'source {script_path}')
        # os.system(-1)
        # os.system(f'initialize_python_env {requirements_file}')


        # Run the script in the current process using the source command
        #subprocess.call(f'source {script_path} && initialize_python_env {requirements_file}', shell=True)

        

    #     # Define the path to your Bash script and the function you want to call
    #     script_path = "/Users/jhummel/Civiform/cloud-deploy-infra/cloud/shared/bin/python_dependencies"
    #     function_name = "initialize_python_env"
    #     function_name_2 = "remove_python_env"

    #     # Define the arguments you want to pass to the function
    #     arg1 = "/Users/jhummel/Civiform/cloud-deploy-infra/cloud/requirements.txt"

    #     # Construct the command to execute the script and call the function
    #     command = f"source {script_path} && {function_name} {arg1}"

    #     # Execute the command as a subprocess and capture its output
    #     process = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE)
    #     output, errors = process.communicate()

    #     # Print the output and errors
    #     print("Output:", output.decode())
    #    # print("Errors:", errors.decode())

    #     # Wait for the subprocess to finish running
    #     process.wait()


        # Print the output
        #print(output)

        # source_script = 'source /path/to/script'
        # my_function = 'my_function /path/to/requirements.txt'
        # ouptu = subprocess.call(source_script, shell= True)
        # print("output")
        # print(output)
        # output1 = subprocess.call(my_function, shell= True)
        # print(output1)


        # source_script = 'source /Users/jhummel/Civiform/cloud-deploy-infra/cloud/shared/bin/python_dependencies'
        # initialize_python_env = 'initialize_python_env /Users/jhummel/Civiform/cloud-deploy-infra/cloud/requirements.txt'
        # output = subprocess.call(source_script, shell= True)
        # print("output")
        # print(output)
        # output1 = subprocess.call(initialize_python_env, shell= True)
        # print(output1)

        # enable_env_var_docs_parser
        # print("Parser installed?")
        # self.assertEqual(True, import_env_var_docs_parser())
        # disable_env_var_docs_parser
        # self.assertEqual(False, import_env_var_docs_parser())


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

    def test_value_regex_ignored_for_not_required_and_not_provided__in_infra_variable_definitions(self):
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

    # TODO  (jhummel)
    # - test by installing package etc.
    # - a config gets loaded correctly
    # - env-var-docs gets loaded correctly
    # - infra variables get loaded correctly
    # - validation of server variables is done correctly
    # - terraform variables work for index list
    # - terraform variables work for server variables

    def test_validate_correct_values_in_config__for_server_variables(self):
        env_var_docs_parser = import_env_var_docs_parser()

        if not env_var_docs_parser == None:
            config_fields = {"FOO_0": "somenumbers123", 
                             "FOO_1": "true",
                             "FOO_2": "value1",
                             "FOO_3": "grey", 
                             "FOO_4": "24"}            
            civiform_server_env_vars = {} 

            # See comments on the specifics we pass correct values for
            civiform_server_env_vars["FOO_0"] = env_var_docs_parser.Variable(
                description='description', 
                type='string',              # normal string
                required=False, 
                values=None,                # with no specified values
                regex=None,                 # or regex to check
                regex_tests=None)
            civiform_server_env_vars["FOO_1"] = env_var_docs_parser.Variable(
                description='description', 
                type='bool',                # boolean, needs boolean value
                required=True,              # and required -> has to be present
                values=None, 
                regex=None, 
                regex_tests=None)
            civiform_server_env_vars["FOO_2"] = env_var_docs_parser.Variable(
                description='description', 
                type='string',              # string 
                required=True, 
                values="value1, value2",    # with specific values
                regex=None, 
                regex_tests=None)
            civiform_server_env_vars["FOO_3"] = env_var_docs_parser.Variable(
                description='description', 
                type='string',              # string 
                required=True, 
                values=None,
                regex="gr(a|e)y",                 # that matches a regex
                regex_tests=None)
            civiform_server_env_vars["FOO_4"] = env_var_docs_parser.Variable(
                description='description', 
                type='int',                 # int has to be int value
                required=True, 
                values=None, 
                regex=None, 
                regex_tests=None)

            config_loader = ConfigLoader()
            validation_errors = config_loader._validate_civiform_server_env_vars(civiform_server_env_vars, config_fields)
            self.assertEqual([], validation_errors)
    
    #TODO(jhummel) enable the test
    def test_validate_incorrect_values_in_config__for_server_variables(self):
        env_var_docs_parser = import_env_var_docs_parser()

        if not env_var_docs_parser == None:
            config_fields = {"FOO_1": "none_boolean_string",
                             "FOO_2": "value3",
                             "FOO_3": "gry", 
                             "FOO_4": "none_int_string"}            
            civiform_server_env_vars = {} 

            # See comments on the specifics we pass correct values for
            civiform_server_env_vars["FOO_0"] = env_var_docs_parser.Variable(
                description='description', 
                type='string',              
                required=True,              # Required but missing in values
                values=None,                
                regex=None,                 
                regex_tests=None)
            civiform_server_env_vars["FOO_1"] = env_var_docs_parser.Variable(
                description='description', 
                type='bool',                # Boolean, but value is other
                required=True,     
                values=None, 
                regex=None, 
                regex_tests=None)
            civiform_server_env_vars["FOO_2"] = env_var_docs_parser.Variable(
                description='description', 
                type='string',              # string 
                required=True, 
                values="value1, value2",    # does not stick to specific values
                regex=None, 
                regex_tests=None)
            civiform_server_env_vars["FOO_3"] = env_var_docs_parser.Variable(
                description='description', 
                type='string',              # string 
                required=True, 
                values=None,
                regex="gr(a|e)y",           # does not matche regex
                regex_tests=None)
            civiform_server_env_vars["FOO_4"] = env_var_docs_parser.Variable(
                description='description', 
                type='int',                 # int has, but is not int value
                required=True, 
                values=None, 
                regex=None, 
                regex_tests=None)

            config_loader = ConfigLoader()
            validation_errors = config_loader._validate_civiform_server_env_vars(civiform_server_env_vars, config_fields)
            self.assertEqual(["'FOO_0' is required but not set", 
                              "'FOO_1' is required to be either 'true' or 'false', got none_boolean_string", 
                              "'FOO_2': 'value3' is not a valid value. Valid values are value1, value2", 
                              "'FOO_3': 'gry' does not match validation regular expression 'gr(a|e)y'", 
                              "'FOO_4' is required to be an integer: invalid literal for int() with base 10: 'none_int_string'"],
                              validation_errors)

    def test_get_terraform_variables():
        env_var_docs_parser = import_env_var_docs_parser()
        if not env_var_docs_parser == None:
            config_loader = ConfigLoader()

            defs = {
                "FOO_0": {
                    "required": True,
                    "secret": False,
                    "tfvar": False,
                    "type": "string"
                },
                "FOO_1": {
                    "required": True,
                    "secret": False,
                    "tfvar": True, 
                    "type": "string"
                },
            }
            config_loader._infra_variable_definitions = defs

            config_loader._civiform_server_env_var_docs = {} 
            config_loader._civiform_server_env_var_docs["FOO_2"] = env_var_docs_parser.Variable(
                description='description', 
                type='index-list',              
                required=True,
                values=None,                
                regex=None,                 
                regex_tests=None)
            
            
            config_loader._config_fields =
            config_loader._civiform_server_env_var_docs = 
            config_loader.get_terraform_variables()
            
            
        



#TODO(jhummel) make path portable
def enable_env_var_docs_parser():
    script_path = '/Users/jhummel/Civiform/cloud-deploy-infra/cloud/shared/bin/python_dependencies'
    function_name = 'python_dependencies::initialize_python_env'
    result = subprocess.run([script_path, function_name], shell=True, capture_output=True)
    yield
    assert result.returncode == 0

#TODO(jhummel) make path portable
def disable_env_var_docs_parser():
    script_path = '/Users/jhummel/Civiform/cloud-deploy-infra/cloud/shared/bin/python_dependencies'
    function_name = 'python_dependencies::remove_python_env'
    result = subprocess.run([script_path, function_name], shell=True, capture_output=True)
    yield
    assert result.returncode == 0
    

def import_env_var_docs_parser():
    try:
        env_var_docs_parser = importlib.import_module("env_var_docs.parser")
        return env_var_docs_parser
    except ModuleNotFoundError:
            return None



if __name__ == "__main__":
    unittest.main()
