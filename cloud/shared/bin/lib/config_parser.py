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

        with open("./civiform_config.sh") as config_file:
            for line in config_file:
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
                
                    key = key_and_value[0]
                    
                    
                    config_values[key_and_value[0]] = key_and_value[1]    
          
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


    

    
    

    
