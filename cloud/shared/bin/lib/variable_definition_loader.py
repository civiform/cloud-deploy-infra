import os
import json


class VariableDefinitionLoader:
    """ 
    Loads all variables from a variable definition json file.
    Validation of the data of the variable definitions should be
    handled separately 
    """

    def __init__(self, variable_definitions={}):
        self.variable_definitions: dict = variable_definitions

    def load_definition_file(self, definition_file_path: str):
        with open(definition_file_path, "r") as file:
            definitions = json.loads(file.read())

            for name, definition in definitions.items():
                if name in self.variable_definitions:
                    raise RuntimeError(
                        f"Duplicate variable name: {name} at {definition_file_path}"
                    )

                self.variable_definitions[name] = definition

    def get_variable_definitions(self) -> dict:
        return self.variable_definitions
