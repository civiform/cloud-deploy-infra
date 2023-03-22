import os


class ConfigParser:
    '''
       ConfigParser reads a configuration file in the format (.sh) into a 
       dictionary that contains key value pairs that define env variables 
       and their value
       
       This class serves as an intermediate step while we are migrating away 
       from .sh, which set env variables that we use to configure the system
       towards .env files which configuration values are read from directly.

       Once all civic entities have migrated to the.env format, this class 
       should be removed
    '''

    def parse_config(self, config_file):
        config_values: dict = {}
        if not os.path.exists(config_file):
            exit(f"Cannot find file {config_file}")

        print(f"Loading config from {config_file}")

        with open(config_file) as config_file:
            for line in config_file:
                # Ignore empty lines and comments
                if (line.strip() and not line.startswith("#")):

                    # expect every remaining line to start with "export"  
                    # extract the key value pairs without the "export"
                    export_string = "export "
                    if not line.startswith(export_string):
                        raise ValueError(
                            f"Error, Invalid line found:\n{line}\nThe config file should contain only exported system variables in the format: export VARIABLE_NAME=variable_value"
                        )
                    key_and_value = line[len(export_string):].strip(
                    ).split("=", 1)


                    var_name = key_and_value[0]
                    print(var_name)
                    var_value = self.strip_quotes(key_and_value[1])
                    print(var_value)

                    count_hash = var_value.count('#')  
                    if count_hash != 0:  
                        raise UserWarning(
                            f"'#' found in env variable definition: '{line}'. \nInline comments are not allowed and all characters, including '#' will be considered part of the value."
                        )

                    config_values[var_name] = var_value

        return config_values

    def strip_quotes(self, string_to_strip):
        stripped_string = string_to_strip
        if string_to_strip.startswith("\""):
            stripped_string = stripped_string[1:]
        if string_to_strip.endswith("\""):
            stripped_string = stripped_string[:len(stripped_string) - 1]
        return stripped_string
