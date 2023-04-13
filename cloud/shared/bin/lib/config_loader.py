import importlib
import os
import re
import urllib.error
import urllib.request
import typing

from cloud.shared.bin.lib.config_parser import ConfigParser
from cloud.shared.bin.lib.print import print
from cloud.shared.bin.lib.variable_definition_loader import load_variables


class ConfigLoader:
    """Handles validating and getting data from the configuration/variable
    files.
    
    Call load_config to get the variable definitions and corresponding env
    variables. Will return if the config is valid and the validation errors.
    
    Provides getters to return values from the config.
    """

    def __init__(self):
        self._config_fields = {}
        """Fields set in the civiform_config.sh file. Each field may or may not
        be a known configuration option.
        """

        self._civiform_server_env_var_docs = {}
        """Environment variable configuration options that the CiviForm server
        reads from, as documented in
        https://github.com/civiform/civiform/blob/main/server/conf/env-var-docs.json.
        """

        self._infra_variable_definitions = {}
        """Additional configuration options declared by the cloud deploy system:

        - https://github.com/civiform/cloud-deploy-infra/blob/main/cloud/shared/variable_definitions.json
        - https://github.com/civiform/cloud-deploy-infra/blob/main/cloud/aws/templates/aws_oidc/variable_definitions.json
        - https://github.com/civiform/cloud-deploy-infra/blob/main/cloud/aws/templates/aws_oidc/variable_definitions.json

        TODO(https://github.com/civiform/civiform/issues/4293): remove CiviForm
        server environment variables from the infra variable definition files.
        """


    def load_config(self, config_file):
        self._config_fields = self._load_config_fields(config_file)
        self._infra_variable_definitions = self._load_infra_variables()
        self._civiform_server_env_var_docs = self._load_civiform_server_env_vars(
        )

        return self.validate_config()

    def _load_config_fields(self, config_file):
        """Returns a map containing key value pairs from all entries in the config file.
        """
        config_parser = ConfigParser()
        config_fields = config_parser.parse_config(config_file)
        self._export_env_variables(config_fields)
        return config_fields

    # TODO(https://github.com/civiform/civiform/issues/4293): remove this when
    # the local deploy system does not read values from env variables anymore.
    # Currently some env variables are read from local deploy code (legacy
    # because the system used to be written in bash)
    def _export_env_variables(self, config):
        """Accepts a map of env variable names and values and exports them as
        environment variables .
        """
        for key, value in config.items():
            os.environ[key] = value

    def _load_infra_variables(self) -> dict:
        """Returns variable definitions in the shared and cloud-specific
        variable_definitions.json files.

        _config_fields() MUST be called before calling this function.
        """
        shared_vars = load_variables(
            os.path.join(
                os.getcwd(), "cloud", "shared", "variable_definitions.json"))
        template_vars = load_variables(
            os.path.join(self.get_template_dir(), "variable_definitions.json"))
        return shared_vars | template_vars

    def _load_civiform_server_env_vars(self) -> dict:
        """Returns environment variables in
        https://github.com/civiform/civiform/tree/main/server/conf/env-var-docs.json.

        
        This function is currently disabled because it relies on the env_var_docs module
        (https://github.com/civiform/civiform/tree/main/env-var-docs/parser-package)
        being installed. If the module is not
        available for import, this function does nothing and returns an empty
        map.

        _config_fields() MUST be called before calling this function.
        """

        print("Loading civiform server variables")
        
        try:
            env_var_docs_parser = importlib.import_module("env_var_docs.parser")
        except ModuleNotFoundError:
            print(
                "env_var_docs package not installed, disabling dynamic civiform server environment variable forwarding"
            )
            return {}

        # Download the env-var-docs.json version that corresponds with CIVIFORM_VERSION.
        civiform_version = self.get_civiform_version()
        
        # TODO(#)Support versioning of env-var-docs.json files. We disable the use for older versions to reduce
        # the risk of backwards compatibility issues, a risk remains though. 
        if not civiform_version=="latest":
            print (
                "Disabling dynamic civiform server environment variable forwarding, because it is only supported for the 'latest' version"
            )
            return {}

        url = f"https://raw.githubusercontent.com/civiform/civiform/main/server/conf/env-var-docs.json"
        
        try:
            with urllib.request.urlopen(url) as f:
                docs = f.read()
        except urllib.error.URLError as e:
            exit(f"Could not download {url}: {e}")    

            out = {}
            def record_var(node):
                if isinstance(node.details, env_var_docs_parser.Variable):
                    out[node.name] = node.details

            errors = env_var_docs_parser.visit(docs, record_var)
            if len(errors) != 0:
                # Should never happen because we ensure env-var-docs.json file
                # is valid before allowing changes to be committed.
                raise RuntimeError(f"{url} is not valid: {errors}")
            return out

    # TODO(https://github.com/civiform/civiform/issues/4293): add validations
    # that every variable in civiform_config.sh is a valid documented variable.
    # This would catch typos.
    def validate_config(self):
        errors = []
        errors.extend(self._validate_infra_variables(self._infra_variable_definitions, self._config_fields))
        errors.extend(self._validate_civiform_server_env_vars(self._civiform_server_env_var_docs, self._config_fields))
        return errors


    def _validate_infra_variables(self, infra_variable_definitions: dict, config_fields: dict) -> list[str]:
        """Returns any validation errors for fields in config_fields that have
        definitions in infra_variable_definitions.
        """
        validation_errors = []

        for name, definition in infra_variable_definitions.items():
            config_value = config_fields.get(name)

            if config_value is None:
                if definition.get("required", False):
                    validation_errors.append(
                        f"'{name}' is required but not set")
                continue

            if definition.get("type") == "enum":
                enum_values = definition.get("values")
                if config_value not in enum_values:
                    validation_errors.append(
                        f"'{name}': '{config_value}' is not a valid enum value. Valid values are {enum_values}"
                    )
                    continue

            value_regex = definition.get("value_regex", None)
            if value_regex:
                # TODO(#2887): If we validate variable definitions prior to
                # trying to validate an actual configuration, we can assume that
                # this will always be set if value_regex is provided.
                # There is currently a presumbit check (validate_variable_definitions)
                # but no code that does the check at runtime to catch isses
                # during development.
                validation_error_message = definition.get(
                    "value_regex_error_message", None)
                if not validation_error_message:
                    raise ValueError(
                        f"'{name}': no value_regex_error_message configured")
                if not re.compile(value_regex).fullmatch(config_value):
                    validation_errors.append(
                        f"'{name}': '{config_value}' not valid: {validation_error_message}"
                    )

        return validation_errors

    def _validate_civiform_server_env_vars(self, env_var_docs: dict, config_fields: dict) -> list[str]:
        """Returns any validation errors for fields in config_fields that have
        definitions in env_var_docs.
        """
        validation_errors = []

        for name, variable in env_var_docs.items():
            # TODO: current support for setting an index-list variables is a
            # comma-separated string. If we support setting like VAR.0, VAR.1,
            # we need update searching though config_fields to support that
            # because the civiform_server_env_var_definitions name is VAR.
            config_value = config_fields.get(name)

            if config_value is None:
                if variable.required:
                    validation_errors.append(
                        f"'{name}' is required but not set")
                continue

            # Variable types are 'string', 'int', 'bool', or 'index-list'.
            if variable.type == "string":
                if variable.values is not None:
                    if config_value not in variable.values:
                        validation_errors.append(
                            f"'{name}': '{config_value}' is not a valid value. Valid values are {variable.values}"
                        )
                        continue

                if variable.regex is not None:
                    if re.match(variable.regex, config_value) == None:
                        validation_errors.append(
                            f"'{name}': '{config_value}' does not match validation regular expression '{variable.regex}'"
                        )
                        continue

            if variable.type == "int":
                try:
                    int(config_value)
                except ValueError as e:
                    validation_errors.append(
                        "f'{name}' is required to be an integer: {e}")
                    continue

            if variable.type == "bool":
                if config_value not in ["true", "false"]:
                    validation_errors.append(
                        f"'{name}' is required to be either 'true' or 'false', got {config_value}"
                    )
                    continue

        return validation_errors


    def get_terraform_variables(self):
        return self._get_terraform_variables(
            self._config_fields, self._infra_variable_definitions,
            self._civiform_server_env_var_docs)

    def _get_terraform_variables(
            self, config_fields: dict, infra_variable_definitions: dict,
            civiform_server_env_var_definitions: dict):
        out = {}

        # TODO(#4612) 
        for name, definition in infra_variable_definitions.items():
            if not definition.get("tfvar", False):
                continue

            if name in config_fields:
                out[name] = config_fields[name]

        if len(civiform_server_env_var_definitions) != 0:
            env_vars = {}
            for name, variable in civiform_server_env_var_definitions.items():
                if name in config_fields:
                    if variable.type == "index-list":
                        i = -1
                        for item in value.split(","):
                            i += 1
                            env_vars[f"{name}.{i}"] = item.strip()
                    else:
                        env_vars[name] = config_fields[name]
            out["civiform_server_environment_variables"] = env_vars

        return out

    @property
    def backend_vars_filename(self):
        return "backend_vars"

    @property
    def tfvars_filename(self):
        return "setup.auto.tfvars"

    @property
    def app_prefix(self):
        return self._config_fields.get("APP_PREFIX")

    @property
    def aws_region(self):
        return self._config_fields.get("AWS_REGION", "us-east-1")

    @property
    def civiform_mode(self):
        return self._config_fields.get("CIVIFORM_MODE")

    def is_test(self):
        return self.civiform_mode == "test"

    @property
    def use_local_backend(self):
        return self._config_fields.get("USE_LOCAL_BACKEND", False)

    @property
    def skip_confirmations(self):
        return self._config_fields.get("SKIP_CONFIRMATIONS", False)

    def get_config_var(self, variable_name):
        return self._config_fields.get(variable_name)

    def get_cloud_provider(self):
        return self._config_fields.get("CIVIFORM_CLOUD_PROVIDER")

    def get_base_url(self):
        return self._config_fields.get("BASE_URL")

    def get_civiform_version(self):
        v = self._config_fields.get("CIVIFORM_VERSION")
        print(v)
        if v is None:
            exit("CIVIFORM_VERSION is required to be set in the config file")
        return v

    def get_template_dir(self):
        template_dir = self._config_fields.get("TERRAFORM_TEMPLATE_DIR")
        if template_dir is None or not os.path.exists(template_dir):
            exit(f"Could not find template directory {template_dir}")
        return template_dir