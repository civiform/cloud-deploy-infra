import json
import os


def load_variables_definitions(definition_file_path: str) -> dict:
    """Returns all definitions in a variable definitions file."""
    out = {}
    with open(definition_file_path) as f:
        # note: loading automatically removes duplicates
        variable_definitions = json.load(f)
        for name, definition in variable_definitions.items():
            out[name] = definition
    return out
