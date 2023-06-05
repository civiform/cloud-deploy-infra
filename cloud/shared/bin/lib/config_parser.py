import os
import re


class ConfigParser:
    '''
       ConfigParser reads a configuration file in the format (.sh) into a 
       dictionary that contains key value pairs that define env variables 
       and their value.
       
       TODO(#4293) Continue the migration by accepting an .env file instead
       of an .sh file and providing migration steps to civic entities.
    '''

    def parse_config(self, config_file):
        config_values: dict = {}
        if not os.path.exists(config_file):
            exit(f"Config Parser cannot find config file: {config_file}")

        print(f"Parsing config from {config_file}")

        with open(config_file) as config_file:
            for line in config_file:
                # Ignore empty lines and comments
                if (line.strip() and not line.startswith("#")):

                    # expect every remaining line to start with "export"
                    export_string = "export "
                    if not line.startswith(export_string):
                        raise ValueError(
                            f"Error, Invalid line found:\n{line}\nThe config file should contain only exported system variables in the format: export VARIABLE_NAME=variable_value"
                        )
                    # extract the key value pairs without the "export"
                    key_and_value_with_comments = line[len(export_string
                                                          ):].strip().split(
                                                              "=", 1)

                    var_name = key_and_value_with_comments[0].strip()

                    # strip out in line comments and remove quotes and blanks
                    value = re.split(r'\s+#', key_and_value_with_comments[1])[0]
                    formatted_value = self.strip_quotes(value.strip()).strip()

                    config_values[var_name] = formatted_value

        return config_values

    def strip_quotes(self, string_to_strip):
        stripped_string = string_to_strip
        if string_to_strip.startswith("\""):
            stripped_string = stripped_string[1:]
        if string_to_strip.endswith("\""):
            stripped_string = stripped_string[:len(stripped_string) - 1]
        return stripped_string
