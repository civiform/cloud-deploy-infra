import subprocess
import shlex
import os
import requests
import re

from cloud.shared.bin.lib.config_parser import ConfigParser
from cloud.shared.bin.lib.variable_definition_loader import VariableDefinitionLoader


class ConfigLoader:
    """
    Config Loader
      Handles validating and getting data from the configuration/variable files
    
      Call load_config to get the variable definitions and corresponding env
      variables. Will return if the config is valid and the validation errors.
    
      Provides getters to return values from the config.
    """

    @property
    def tfvars_filename(self):
        return os.environ["TF_VAR_FILENAME"]

    @property
    def backend_vars_filename(self):
        return os.environ["BACKEND_VARS_FILENAME"]

    @property
    def app_prefix(self):
        return os.environ["APP_PREFIX"]

    @property
    def aws_region(self):
        # NOTE: should we make AWS_REGION required and avoid having a default
        # value here?
        return os.environ.get("AWS_REGION", "us-east-1")

    @property
    def civiform_mode(self):
        return os.environ["CIVIFORM_MODE"]

    @property
    def use_local_backend(self):
        return os.getenv("USE_LOCAL_BACKEND", False)

    @property
    def skip_confirmations(self):
        return os.getenv("SKIP_CONFIRMATIONS", False)

    class VersionNotFoundError(Exception):
        pass

    def load_config(self, config_file):
        self._load_config(config_file)
        self._load_variable_definitions()
        return self.validate_config()

    def _load_variable_definitions(self):
        # get the shared variable definitions
        variable_def_loader = VariableDefinitionLoader()
        cwd = os.getcwd()
        definition_file_path = os.path.join(
            cwd, "cloud", "shared", "variable_definitions.json")
        variable_def_loader.load_definition_file(definition_file_path)
        shared_definitions = variable_def_loader.get_variable_definitions()

        template_definitions_file_path = os.path.join(
            self.get_template_dir(), "variable_definitions.json")
        variable_def_loader.load_definition_file(template_definitions_file_path)
        self.variable_definitions = variable_def_loader.get_variable_definitions(
        )

    def _load_config(self, config_file):
        config_parser = ConfigParser()
        self.configs = config_parser.parse_config(config_file)
        self._export_env_variables(self.configs)

    def _get_shared_variable_definitions(self):
        variable_def_loader = VariableDefinitionLoader()
        variable_def_loader.load_repo_variable_definitions_files()
        return variable_def_loader.get_variable_definitions()

    # TODO(#4293), remove this when the local deploy system does not read values from env
    # variables anymore. Currently some env variables are read from local deploy code
    # (legacy because the system used to be written in bash)
    def _export_env_variables(self, config):
        '''
            Accepts a map of env variable names and values and exports them
            as environment variables 
        '''
        for key, value in config.items():
            os.environ[key] = value

    # TODO(#4293) In the future we should ensure that all variables are
    # in the variable defintions files.
    def _validate_config(self, variable_definitions: dict, configs: dict):
        validation_errors = []

        for name, definition in variable_definitions.items():
            is_required = definition.get("required", False)
            config_value = configs.get(name, None)

            if config_value is None:
                if is_required:
                    validation_errors.append(
                        f"[{name}] required, but not provided")
                continue

            is_enum = definition.get("type") == "enum"

            if is_enum:
                if config_value not in definition.get("values"):
                    validation_errors.append(
                        f'[{name}] \'{config_value}\' is not a supported enum value. Want a value in [{", ".join(definition.get("values"))}]'
                    )

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
                        f"[{name}] no value_regex_error_message configured")
                if not re.compile(value_regex).fullmatch(config_value):
                    validation_errors.append(
                        f"[{name}] '{config_value}' not valid: {validation_error_message}"
                    )

        return validation_errors

    # TODO((#4293) Once #132 is submitted, use this function to download the correct
    # version of the env-var-docs.json
    def get_commit_sha_for_release(self, tag: str) -> str:
        """Get the commit sha for the release specified in the tag

          We are calling the GitHub API with unauthenticated request, which are rate-limited.
          The rate limit allows for up to 60 requests per hour  associated with the originating 
          IP address.
        """
        if tag.strip() == 'latest':
            # Translate "latest" into a version number
            url = f"https://api.github.com/repos/civiform/civiform/releases/latest"
            response = requests.get(url)
            if response.status_code == 200:
                newtag = response.json()["tag_name"]
                tag = response.json()["tag_name"]
            else:
                raise self.VersionNotFoundError(
                    f"Error: 'latest' could not be translated to a release tag {response.status_code} - {response.json()['message']}"
                )

        url = f"https://api.github.com/repos/civiform/civiform/git/refs/tags/{tag}"
        response = requests.get(url)

        if response.status_code == 200:
            commit_sha = response.json()["object"]["sha"]
            return commit_sha
        else:
            raise self.VersionNotFoundError(
                f"The commit sha for version {tag} could not be found. Are you using a valid tag such as latest or a valid version number like v1.0.0?\n {response.status_code} - {response.json()['message']}"
            )

    def validate_config(self):
        return self._validate_config(self.variable_definitions, self.configs)

    def get_config_var(self, variable_name):
        return self.configs.get(variable_name)

    def get_cloud_provider(self):
        return self.configs.get("CIVIFORM_CLOUD_PROVIDER")

    def get_base_url(self):
        return self.configs.get("BASE_URL")

    def get_template_dir(self):
        template_dir = self.configs.get("TERRAFORM_TEMPLATE_DIR")
        if template_dir is None or not os.path.exists(template_dir):
            exit(f"Could not find template directory {template_dir}")
        return template_dir

    def is_test(self):
        return self.civiform_mode == "test"

    def get_config_variables(self):
        return self.configs

    def _get_terraform_variables(
            self, variable_definitions: dict, configs: dict):
        tf_variables = list(
            filter(
                lambda x: variable_definitions.get(x).get("tfvar"),
                self.variable_definitions,
            ))
        tf_config_vars = {}
        for key, value in configs.items():
            if key in tf_variables:
                tf_config_vars[key] = value
        return tf_config_vars

    def get_terraform_variables(self):
        return self._get_terraform_variables(
            self.variable_definitions, self.configs)
