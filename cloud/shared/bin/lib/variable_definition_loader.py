import json
import os


def load_variables(definition_file_path: str) -> dict:
    """Returns all definitions in a variable definitions file."""
    out = {}
    with open(definition_file_path) as f:
        variable_definitions = json.load(f)
        for name, definition in variable_definitions.items():
            if name in out:
                raise RuntimeError(
                    f"Duplicate variable name: {name} at {definition_file_path}"
                )
            out[name] = definition
    return out
