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
            print(f"\n\n\n\n\n")
            for line in config_file:
                # Ignore empty lines and comments
                if (line.strip() and not line.startswith("#")):
                    export_string ="export "
                    if not line.startswith(export_string):
                        print("Error, Invalid line found. The config file should contain only exported system variables in the format\"export VARIABLE_NAME=variable_value\"")
                   
                    # cut off the export statement
                    key_value_and_comments = line[len(export_string):].strip().split(" ")
                    key_and_value = {}

                    # remove comments on the line and give a warning if none comment text is found
                    if not len(key_value_and_comments) == 1 and not key_value_and_comments[1].startswith("#"):
                        print(f"Warning: Unexpected string after {key_value_and_comments[0]} string will be ignored")
                        
                    key_and_value = key_value_and_comments[0].split("=")
                
                    var_name = key_and_value[0]
                    var_value = self.strip_quotes(key_and_value[1])
                    config_values[var_name] = var_value    

        print("\n\n\n config values in config parser:")  
        print(config_values)           
        return config_values
    
    def strip_quotes(self, string_to_strip):
        print(f"STRINGS: {string_to_strip}")
        stripped_string = ""
        if string_to_strip.startswith("\""):
            stripped_string = string_to_strip[1:]
            print(f"strip front: {stripped_string}" )
        if string_to_strip.endswith("\""):
            stripped_string = stripped_string[:len(stripped_string)-1]
            print(f"strip end: {stripped_string}" )

        return stripped_string
            

    

    
    

    
