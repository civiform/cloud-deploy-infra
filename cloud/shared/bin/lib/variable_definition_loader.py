import os
import json


class VariableDefinitionLoader:
    """ 
    Loads all variables from a valid variable definition json file.
    """

    def __init__(self, variable_definitions={}):
        self.variable_definitions: dict = variable_definitions

    def load_definition_file(self, definition_file_path: str):
        with open(definition_file_path, "r") as file:
            # json.loads() returns a dictionary, keeping the last
            # occurance and thus removes duplicates.
            # To detect them we would need to write our own parser.
            definitions = json.loads(file.read())

            for name, definition in definitions.items():
                self.variable_definitions[name] = definition

    def get_variable_definitions(self) -> dict:
        return self.variable_definitions
