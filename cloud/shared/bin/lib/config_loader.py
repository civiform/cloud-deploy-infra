import importlib
import io
import os
import requests
import re
import ssl
import typing
import urllib.error
import urllib.request
from typing import List

from cloud.shared.bin.lib.config_parser import ConfigParser
from cloud.shared.bin.lib.print import print
from cloud.shared.bin.lib.variable_definition_loader import \
    load_variables_definitions

CIVIFORM_SERVER_VARIABLES_KEY = "civiform_server_environment_variables"


class ConfigLoader:
    """Handles validating and getting data from the configuration/variable
    files.
    
    Call load_config to get the variable definitions and corresponding env
    variables. Will return if the config is valid and the validation errors.
    
    Provides getters to return values from the config.
    """

    def __init__(self):
        self._config_fields = {}
        """Configuration fields passed to this deployment via civiform_config.sh file. 
        Each field may or may not be a known configuration option.
        """

        self._civiform_server_env_var_docs = {}
        """Environment variable configuration options that the CiviForm server
        reads from, as documented in
        https://github.com/civiform/civiform/blob/main/server/conf/env-var-docs.json.
        """

        self._infra_variable_definitions = {}
        """Additional configuration options declared by the cloud deploy system in the
        variable definition files:

        - https://github.com/civiform/cloud-deploy-infra/blob/main/cloud/shared/variable_definitions.json
        - https://github.com/civiform/cloud-deploy-infra/blob/main/cloud/aws/templates/aws_oidc/variable_definitions.json
        - https://github.com/civiform/cloud-deploy-infra/blob/main/cloud/azure/templates/azure_saml_ses/variable_definitions.json

        TODO(https://github.com/civiform/civiform/issues/4293): Currently this also includes
        the env variables that are defined in env-var-docs and passed to the server. 
        Remove them when other required changes are completed.
        """

    class VersionNotFoundError(Exception):
        pass

    def load_config(self, config_file: str):
        self._config_fields = self._load_config_fields(config_file)
        self._infra_variable_definitions = self._load_infra_variables()
        self._civiform_server_env_var_docs = self._load_civiform_server_env_vars(
        )

        return self.validate_config()

    def _load_config_fields(self, config_file: str):
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
    def _export_env_variables(self, config: dict):
        """Accepts a map of env variable names and values and exports them as
        environment variables.
        """
        for key, value in config.items():
            os.environ[key] = value

    def _load_infra_variables(self) -> dict:
        """Returns variable definitions in the shared and cloud-specific
        variable_definitions.json files.
        """
        shared_vars = load_variables_definitions(
            os.path.join(
                os.getcwd(), "cloud", "shared", "variable_definitions.json"))
        template_vars = load_variables_definitions(
            os.path.join(self.get_template_dir(), "variable_definitions.json"))
        return shared_vars | template_vars

    def _load_civiform_server_env_vars(self) -> dict:
        """Returns environment variables in
        https://github.com/civiform/civiform/tree/main/server/conf/env-var-docs.json.

        TODO(#4612) Enable the reading of server variables. This function is currently 
        disabled because it relies on the env_var_docs module
        (https://github.com/civiform/civiform/tree/main/env-var-docs/parser-package)
        being installed. If the module is not available for import, this function 
        does nothing and returns an empty map.

        _load_config_fields() MUST be called before calling this function.
        """

        try:
            env_var_docs_parser = importlib.import_module("env_var_docs.parser")
        except ModuleNotFoundError:
            print(
                "env_var_docs package not installed, disabling dynamic civiform server environment variable forwarding"
            )
            return {}

        # Download the env-var-docs.json if there is a version that corresponds to the
        # civiform version of this deployment.
        env_var_docs = self._download_env_var_docs(self.get_civiform_version())
        if env_var_docs is None:
            return {}

        out = {}

        def record_var(node):
            if isinstance(node.details, env_var_docs_parser.Variable):
                out[node.name] = node.details

        errors = env_var_docs_parser.visit(env_var_docs, record_var)
        if len(errors) != 0:
            # Should never happen because we ensure env-var-docs.json file
            # is valid before allowing changes to be committed.
            raise RuntimeError(
                f"the downloaded env-var-docs file is not valid: {errors}")
        return out

    def _download_env_var_docs(self, civiform_version: str):
        """ 
        Downloads the env-var-docs.json from the civiform git repository if there is a version that corresponds to the
        civiform version of this deployment. The env-var-docs.json defines all server variables. 
        """
        try:
            commit_sha = self._get_commit_sha_for_release(civiform_version)
        except:
            return None
        url = f"https://raw.githubusercontent.com/civiform/civiform/{commit_sha}/server/conf/env-var-docs.json"

        try:
            with urllib.request.urlopen(url) as f:
                env_var_docs_bytes = f.read()
        except urllib.error.URLError as e:
            exit(f"Could not download {url}: {e}")
        env_var_docs_text = env_var_docs_bytes.decode("utf-8")
        env_var_docs = io.StringIO(env_var_docs_text)
        return env_var_docs

    # TODO(https://github.com/civiform/civiform/issues/4293): add validations
    # that every variable in civiform_config.sh is a valid documented variable.
    # This would catch typos.
    def validate_config(self):
        errors = []
        errors.extend(
            self._validate_infra_variables(
                self._infra_variable_definitions, self._config_fields))
        errors.extend(
            self._validate_civiform_server_env_vars(
                self._civiform_server_env_var_docs, self._config_fields))
        return errors

    def _validate_infra_variables(
            self, infra_variable_definitions: dict,
            config_fields: dict) -> List[str]:
        """
        Returns any validation errors for fields in config_fields that have
        definitions in infra_variable_definitions.
        """
        validation_errors = []

        for name, definition in infra_variable_definitions.items():
            config_value = config_fields.get(name)

            if config_value is None:
                is_required = definition.get("required", False)
                if is_required:
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

    # TODO((#4293) Once #132 is submitted, use this function to download the correct
    # version of the env-var-docs.json
    def _get_commit_sha_for_release(self, tag: str) -> str:
        """Get the commit SHA for the release specified in the tag.
        
          The tag is a release version number such as "v1.24.0".

          We are calling the GitHub API with unauthenticated requests, which are rate-limited.
          The rate limit allows for up to 60 requests per hour associated with the originating 
          IP address.
        """
        tag = tag.strip()
        if tag == 'latest':
            # Translate "latest" into a version number
            tag = self._get_latest_version_number()

        release_url = f"https://api.github.com/repos/civiform/civiform/git/refs/tags/{tag}"
        release_response = requests.get(release_url)

        if release_response.status_code == 200:
            return self._get_commit_sha_for_tag(release_response.json()["object"]["sha"])
        else:
            raise self.VersionNotFoundError(
                f"The commit sha for version {tag} could not be found. Are you using a valid tag such as latest or a valid version number like v1.0.0? {release_response.status_code} - {release_response.json()['message']}"
            )

    def _get_latest_version_number(self) -> str:
        url = "https://api.github.com/repos/civiform/civiform/releases/latest"
        response = requests.get(url)
        if response.status_code == 200:
            return response.json()["tag_name"]
        else:
            raise self.VersionNotFoundError(
                f"Error: 'latest' could not be translated to a release tag. {response.status_code} - {response.json()['message']}"
            )

    def _get_commit_sha_for_tag(self, tag_commit_sha: str) -> str:
        tag_url = f"https://api.github.com/repos/civiform/civiform/git/tags/{tag_commit_sha}"
        tag_response = requests.get(tag_url)
        if tag_response.status_code == 200:
            commit_sha = tag_response.json()["object"]["sha"]
            return commit_sha
        else:
            raise self.VersionNotFoundError(f"The commit sha {commit_sha} could not be found. {tag_response.status_code} - {tag_response.json()['message']}")

    def _validate_civiform_server_env_vars(
            self, env_var_docs: dict, config_fields: dict) -> List[str]:
        """
        Returns any validation errors for fields in config_fields that have
        definitions in env_var_docs.
        """
        validation_errors = []

        for name, variable in env_var_docs.items():
            config_value = config_fields.get(name)

            # TODO(#4612) Extend env-var-docs to include the required field, use the
            # variable_definitions.json files as the source for the values. env_var_docs does
            # not currently include required field. Therefore this code will never run.
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
                        f"'{name}' is required to be an integer: {e}")
                    continue

            if variable.type == "bool":
                if config_value not in ["true", "false"]:
                    validation_errors.append(
                        f"'{name}' is required to be either 'true' or 'false', got {config_value}"
                    )
                    continue

            # TODO(#4612): Add support for validation of items in an index-list.
            # An Index-list variables VAR is represented as a comma-separated string.
            # Individual fields in VAR can NOT currently be set the same way as on the
            # server by setting VAR.0=value0, VAR.1=value1 etc. Supporting this may not
            # be required, but validation should be supported.

        return validation_errors

    def get_terraform_variables(self):
        return self._get_terraform_variables(
            self._config_fields, self._infra_variable_definitions,
            self._civiform_server_env_var_docs)

    def _get_terraform_variables(
            self, config_fields: dict, infra_variable_definitions: dict,
            civiform_server_env_var_definitions: dict):
        out = {}

        # TODO(#4612) When server variables are not duplicated in the infra
        # variables anymore: support the tfvars field in env-var-docs.json
        # instead or make all server variables "tfvar"s by default.
        for name, definition in infra_variable_definitions.items():
            if not definition.get("tfvar", False):
                continue

            if name in config_fields:
                out[name] = config_fields[name]

        if civiform_server_env_var_definitions:
            env_vars = {}
            for name, variable in civiform_server_env_var_definitions.items():
                if name in config_fields:
                    if variable.type == "index-list":
                        i = -1
                        for item in config_fields[name].split(","):
                            i += 1
                            env_vars[f"{name}.{i}"] = item.strip()
                    else:
                        env_vars[name] = config_fields[name]

            # Infra and server variables are merged before being passed through
            # terraform, which means that, if a variable is in both, values in the server variables
            # take precedence over infra variables. Once #4612 is completed, this should never happen.
            out[CIVIFORM_SERVER_VARIABLES_KEY] = env_vars

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
        return os.getenv("SKIP_CONFIRMATIONS", False)

    def get_config_var(self, variable_name):
        return self._config_fields.get(variable_name)

    def get_cloud_provider(self):
        return self._config_fields.get("CIVIFORM_CLOUD_PROVIDER")

    def get_base_url(self):
        return self._config_fields.get("BASE_URL")

    # TODO() Make the configuration option required as part of the validation
    # instead of manually checking for it here.
    def get_civiform_version(self):
        v = self._config_fields.get("CIVIFORM_VERSION")
        if v is None:
            exit("CIVIFORM_VERSION is required to be set in the config file")
        return v

    def get_template_dir(self):
        template_dir = self._config_fields.get("TERRAFORM_TEMPLATE_DIR")
        if template_dir is None or not os.path.exists(template_dir):
            exit(f"Could not find template directory {template_dir}")
        return template_dir
