"""
Writes a tfvars file with the format
name="value"\n 

If we want to store non string values here we will need to add in the variables
and do a lil more advanced file writing
"""


class TfVarWriter:

    def __init__(self, filepath):
        self.filepath = filepath

    # a json of key: vals to turn into a tfvars
    def write_variables(self, config_vars: dict):
        with open(self.filepath, "w") as tf_vars_file:
            for name, definition in config_vars.items():
                # Special key that has a dict value.
                if name == "civiform_server_environment_variables":
                    tf_vars_file.write(
                        "civiform_server_environment_variables = {\n")
                    for key, value in definition.items():
                        if value is not None:
                            tf_vars_file.write(f'  "{key}"="{value}"\n')
                    tf_vars_file.write("}\n")
                    continue

                if definition is not None:
                    print(f"Name - DEFINITION IS {name} - {definition}")
                    print(definition.get("type"))
                    tf_vars_file.write(f'{name.lower()}="{definition}"\n')
