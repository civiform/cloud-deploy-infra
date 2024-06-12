import json
import os
import re

from cloud.shared.bin.lib.variable_definition_loader import load_variables_definitions

# Loads all configuration variable definition files and validates each
# definition for correctness. Exercised by the accompanying test file
# which is run for every pull request.
#
# Requires that:
#   - Each variable definition file is referenced in
#     def load_repo_variable_definitions_files():
#
#   - All variables have, at minimum, 'type', 'required', and 'secret' fields
#
#   - Variable definitions may include additional configuration based on their
#     type.


# TODO(#2887) generalize validation code to work on all config files and move
#       validation into config_loader.py so validation happens during development
#       rather than only when github action are run during submits.
class ValidateVariableDefinitions:

    def __init__(self, variable_definitions={}):
        self.variable_definitions = variable_definitions

        self.type_specific_validators = {
            "float": self.validate_float_definition_type,
            "integer": self.validate_integer_definition_type,
            "string": self.validate_string_definition_type,
            "enum": self.validate_enum_definition_type,
            "bool": self.validate_bool_definition_type,
            "list": self.validate_list_definition_type,
        }

    def load_repo_variable_definitions_files(self):
        # As more variable definition files are added for each cloud provider,
        # add their paths here.
        cwd = os.getcwd()
        definition_file_paths = [
            f"{cwd}/cloud/shared/variable_definitions.json",
            f"{cwd}/cloud/aws/templates/aws_oidc/variable_definitions.json",
            f"{cwd}/cloud/azure/templates/azure_saml_ses/variable_definitions.json",
        ]

        vars = {}
        for path in definition_file_paths:
            vars.update(load_variables_definitions(path))
        self.variable_definitions = vars

    def get_validation_errors(self):
        all_errors = {}

        for name, definition in self.variable_definitions.items():
            definition_errors = self.validate(definition)

            if len(definition_errors) > 0:
                all_errors[name] = definition_errors

        return all_errors

    def validate(self, variable_definition):
        errors = []

        if not isinstance(variable_definition.get("required", None), bool):
            errors.append("Missing 'required' field.")

        if not isinstance(variable_definition.get("secret", None), bool):
            errors.append("Missing 'secret' field.")

        if not isinstance(variable_definition.get("tfvar", None), bool):
            errors.append("Missing 'tfvar' field.")

        if not isinstance(variable_definition.get("type", None), str):
            errors.append("Missing 'type' field.")
            return errors

        validator = self.type_specific_validators.get(
            variable_definition["type"], None)

        if validator:
            errors.extend(validator(variable_definition))
        else:
            supported_typed = list(self.type_specific_validators.keys())
            errors.append(
                f"Unknown or missing 'type' field. Supported types {supported_typed}"
            )

        return errors

    def validate_float_definition_type(self, variable_definition):
        return []

    def validate_integer_definition_type(self, variable_definition):
        return []

    def validate_bool_definition_type(self, variable_definition):
        return []

    def validate_list_definition_type(self, variable_definition):
        errors = []

        list_type = variable_definition.get("list_type", None)
        supported_types = list(self.type_specific_validators.keys())

        if list_type is None:
            errors.append(
                "'list_type' field is required for list type variables.")
        elif list_type not in supported_types:
            errors.append(
                f"Invalid 'list_type' value '{list_type}'. Supported types are {supported_types}."
            )

        return errors

    def validate_string_definition_type(self, variable_definition):
        maybe_value_regex = variable_definition.get("value_regex", None)
        if maybe_value_regex is None:
            return []

        errors = []
        if not maybe_value_regex or not isinstance(maybe_value_regex, str):
            errors.append("'value_regex' field must be a non-empty string.")
        else:
            try:
                re.compile(maybe_value_regex)
            except re.error:
                errors.append(
                    "'value_regex' can not be compiled as a Python regular expression."
                )

        maybe_value_regex_error_message = variable_definition.get(
            "value_regex_error_message", None)
        if not maybe_value_regex_error_message or not isinstance(
                maybe_value_regex_error_message, str):
            errors.append(
                "'value_regex_error_message' must be provided when 'value_regex' is provided."
            )

        return errors

    def validate_enum_definition_type(self, variable_definition):
        if not isinstance(variable_definition.get("values", None), list):
            return ["Missing 'values' field for enum."]
        return []
