import json
import os
import sys
import tempfile
import yaml
from cli.shared import shell, generate_random_string


class Tenant():
    tenant_config: dict = None
    tenant_config_filename: str = None
    project_id: str = None
    tenant_id: str = None
    tenant_namespace: str = None
    gsa_email: str = None
    ksa_name: str = None
    db_conn: str = None
    db_username: str = None
    env_var_config_map_name: str = None
    env_var_secrets_name: str = None
    static_ip_name: str = None

    props = [
        "cluster_location", "cluster_name", "image", "image_tag", "project_id",
        "region", "ssl_cert_name", "tenant_id", "tf_state_bucket_name",
        "tf_state_tenant_prefix"
    ]

    def __init__(self, tenant_config_filename):
        self.tenant_config_filename = tenant_config_filename

    def turnup(self, k8s_only):
        self._load_tenant_config()

        if not k8s_only:
            tf_vars_file = self._tf_write_vars()
            self._tf_init_and_apply(tf_vars_file)
            self._db_do_service_account_grants()
            self._create_static_ip()

        shell(f"kubectl create namespace {self.tenant_namespace}")

        self._kubectl_create_random_secrets()
        self._kubectl_apply_server_secret_env_vars()
        self._kubectl_apply_server_env_vars()

        helm_vals_file = self._helm_write_values()
        self._helm_install(helm_vals_file)

    def update(self, k8s_only: bool):
        self._load_tenant_config()

        if not k8s_only:
            tf_vars_file = self._tf_write_vars()
            self._tf_init_and_apply(tf_vars_file)

        self._kubectl_apply_server_secret_env_vars()
        self._kubectl_apply_server_env_vars()

        helm_vals_file = self._helm_write_values()
        self._helm_upgrade(helm_vals_file)

    def turndown(self, k8s_only: bool):
        self._load_tenant_config()

        print("Helm delete")
        self._helm_delete()

        print(
            f"Deleting remaining namespace {self.tenant_namespace} resources, if any"
        )
        shell(f"kubectl delete all -n {self.tenant_namespace} --all")
        print(f"Deleting namespace {self.tenant_namespace}")
        shell(f"kubectl delete namespace {self.tenant_namespace}")

        if not k8s_only:
            print("Deleting static IP")

            self._delete_static_ip()
            tf_vars_file = self._tf_write_vars()

            print("tofu destroy")
            self._tf_destroy(tf_vars_file)

    def _create_static_ip(self):
        shell(
            f"gcloud compute addresses create {self.static_ip_name} --global --quiet"
        )

    def _delete_static_ip(self):
        shell(
            f"gcloud compute addresses delete {self.static_ip_name} --global --quiet"
        )

    def _tf_destroy(self, tf_vars_file):
        tofu_path = os.path.abspath("data_plane/tofu")

        # Cloud SQL won't allow deleting the DB user while it still has permissions
        # in postgres. We're deleting the whole DB instance right after this which
        # will also destroy the DB user. Removing the user from TF state is easier
        # than altering the internal DB permissions.
        # shell(f"tofu -chdir={tofu_path} state rm google_sql_user.civiform_user")
        shell(
            f"tofu -chdir={tofu_path} destroy -input=false -var-file={tf_vars_file.name}"
        )

    def _tf_init_and_apply(self, tf_vars_file):
        tofu_path = os.path.abspath("data_plane/tofu")
        backend_config = f"-backend-config='bucket={self.tenant_config['tf_state_bucket_name']}' -backend-config='prefix={self.tenant_config['tf_state_tenant_prefix']}'"

        shell(
            f"tofu -chdir={tofu_path} init -reconfigure -input=false {backend_config}"
        )
        shell(
            f"tofu -chdir={tofu_path} apply -auto-approve -input=false -var-file={tf_vars_file.name} -var='db_enable_public_ip4=true'"
        )

    def _tf_write_vars(self):
        # TODO: use canonical var definitions similar to the AWS deployment for filtering and validating vars
        tf_vars = {
            k: self.tenant_config[k] for k in self.props if k not in [
                "image", "image_tag", "tf_state_bucket_name",
                "tf_state_tenant_prefix"
            ]
        }
        tf_vars['tenant_ksa_name'] = self.ksa_name
        tf_vars['tenant_k8s_namespace'] = f"ns-tenant-{self.tenant_id}"
        tf_vars['db_deletion_protection'] = self.tenant_config[
            'db_deletion_protection'] if 'db_deletion_protection' in self.tenant_config else False

        with tempfile.NamedTemporaryFile(mode="w+", suffix=".tfvars.json",
                                         delete=False) as temp_vars_file:
            temp_vars_file.write(json.dumps(tf_vars, sort_keys=True, indent=2))
            temp_vars_file.write("\n")
            temp_vars_file.close()

            return temp_vars_file

    # While the tenant service account has permission from GCP to connect to the DB instance,
    # the PG database user it connects with has no internal permissions in PG, so we need to
    # grant all database and public schema privileges for the `postgres` internal database to
    # the service account user. Nota bene it's critical that the `postgres` user account
    # performs these grants, otherwise they will appear to succeed but fail silently (the DB logs
    # in the GCP console will reveal "no permissions changed" when this happens). Alternative to
    # running this script: you can use Cloud SQL Studio in the GCP console to set the `postgres`
    # user's password and execute the SQL statements using a browser UI.
    # TODO: rewrite this in Python https://github.com/GoogleCloudPlatform/cloud-sql-python-connector
    #       and remove cloud-sql-proxy from civ.Dockerfile
    def _db_do_service_account_grants(self):
        shell(
            f"./data_plane/service_account_db_grants {self.db_conn} {self.db_username}"
        )

    def _kubectl_create_random_secrets(self):
        shell(
            f"kubectl create secret generic server-secret-key --from-literal='SECRET_KEY={generate_random_string(64)}' --namespace {self.tenant_namespace}"
        )
        shell(
            f"kubectl create secret generic server-api-secret-salt --from-literal='CIVIFORM_API_SECRET_SALT={generate_random_string(16)}' --namespace {self.tenant_namespace}"
        )

    def _kubectl_apply_server_env_vars(self):
        temp = self._write_tempfile(
            ".yaml",
            yaml.dump(
                {
                    'apiVersion': 'v1',
                    'kind': 'ConfigMap',
                    'metadata':
                        {
                            'namespace': self.tenant_namespace,
                            'name': self.env_var_config_map_name
                        },
                    'data': self.tenant_config['server_env_vars']
                }))

        shell(f"kubectl apply -f {temp.name}")

    def _kubectl_apply_server_secret_env_vars(self):
        temp = self._write_tempfile(
            ".yaml",
            yaml.dump(
                {
                    'apiVersion': 'v1',
                    'kind': 'Secret',
                    'metadata':
                        {
                            'namespace': self.tenant_namespace,
                            'name': self.env_var_secrets_name
                        },
                    'stringData': self.tenant_config['server_secret_env_vars']
                }))

        shell(f"kubectl apply -f {temp.name}")
        # don't leave secrets sitting around on the filesystem
        os.remove(temp.name)

    def _helm_write_values(self):
        return self._write_tempfile(
            ".yaml",
            yaml.dump(
                {
                    'dbConnectionName': self.db_conn,
                    'dbUsername': self.db_username,
                    'gsaEmail': self.gsa_email,
                    'ksaName': self.ksa_name,
                    'image': self.tenant_config['image'],
                    'imageTag': self.tenant_config['image_tag'],
                    'nodePoolName': f"np-tenant-{self.tenant_id}",
                    'publicFQDN': f"{self.tenant_id}.tenant.civiform.dev",
                    'sslCertName': self.tenant_config['ssl_cert_name'],
                    'tenantId': self.tenant_id,
                    'namespace': self.tenant_namespace,
                    'envVarConfigMapName': self.env_var_config_map_name,
                    'envVarSecretName': self.env_var_secrets_name,
                    'staticIPName': self.static_ip_name
                }))

    def _write_tempfile(self, suffix, contents):
        temp = tempfile.NamedTemporaryFile("w+", suffix=suffix, delete=False)

        temp.write(contents)
        temp.write("\n")
        temp.close()

        return temp

    def _helm_install(self, helm_values_file):
        shell(
            f"helm install -f {helm_values_file.name} tenant-{self.tenant_id} ./data_plane/kubernetes/tenant_chart"
        )

    def _helm_upgrade(self, helm_values_file):
        shell(
            f"helm upgrade -f {helm_values_file.name} tenant-{self.tenant_id} ./data_plane/kubernetes/tenant_chart"
        )

    def _helm_delete(self):
        shell(
            f"helm delete tenant-{self.tenant_id} ./data_plane/kubernetes/tenant_chart"
        )

    def _load_tenant_config(self):
        try:
            with open(self.tenant_config_filename, 'r') as file:
                self.tenant_config = yaml.safe_load(file)

        except FileNotFoundError:
            print(
                f"Error: tenant_config file not found: {self.tenant_config_filename}"
            )
            exit(1)
        except yaml.YAMLError as e:
            print(f"Error: Invalid YAML format: {e}")
            exit(1)

        # TODO: do a hell of a lot more validation than this
        errors = []
        for item in self.props:
            if item not in self.tenant_config:
                errors.append(f"Error: missing {item}")

        if errors:
            for error in errors:
                print(error)
                exit(1)

        self.project_id = self.tenant_config["project_id"]
        self.tenant_id = self.tenant_config["tenant_id"]
        self.tenant_namespace = f"ns-tenant-{self.tenant_id}"
        self.gsa_email = f"civiform-tenant-sa-{self.tenant_id}@{self.project_id}.iam.gserviceaccount.com"
        self.ksa_name = f"sa-tenant-{self.tenant_id}"
        self.db_conn = f"{self.project_id}:{self.tenant_config['region']}:civiform-tenant-{self.tenant_id}"
        self.db_username = self.gsa_email.replace(".gserviceaccount.com", "")
        self.env_var_config_map_name = f"tenant-{self.tenant_id}-server-env-vars"
        self.env_var_secrets_name = f"tenant-{self.tenant_id}-server-secrets"
        self.static_ip_name = f"tenant-ingress-{self.tenant_id}"
