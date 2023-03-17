import os


class ConfigParser:
    '''
       ConfigMigrator reads an old configuration file in the format (.sh)
       and converts it into two new styly config files (.env), which separate
       the configuration values into server config values and local deploy
       system config values.

       Once all civic entities have migrated, this class should be removed
    '''
    
    def parse_config(self, config_file):
        config_values: dict = {}
        print(f"PARSING {config_file}")

        if not os.path.exists(config_file):
            exit(f"Cannot find file {config_file}")

        print(f"Getting config from {config_file}")

        with open(config_file) as config_file:
            for line in config_file:
                print(line)
                # Ignore empty lines and comments
                if (line.strip() and not line.startswith("#")):
                    export_string ="export "
                    if not line.startswith(export_string):
                        print("Error, Invalid line found. The config file should contain only exported system variables in the format\"export VARIABLE_NAME=variable_value\"")
                   
                    # cut off the export statement
                    key_and_value = line[len(export_string):].strip().split("=")
                    if not len(key_and_value) == 2:

                        print(f"Warning: Unexpected string after {key_and_value} will be ignored")
                        continue
                
                    var_name = key_and_value[0]
                    var_value = self.strip_quotes(key_and_value[1])
                    config_values[var_name] = var_value    
          
        print(config_values)           
        return config_values
    
    def strip_quotes(self, string_to_strip):
        stripped_string = ""
        if string_to_strip.startswith("\""):
            stripped_string = string_to_strip[1:]
        if string_to_strip.endswith("\""):
            stripped_string = stripped_string[:len(stripped_string)-2]
        print(f"strings: {string_to_strip}, {stripped_string}")
        return stripped_string
            
        
        return stripped_string


    

    
    

    
