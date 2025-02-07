locals {
  # The hard-coded zero indexes here are necessary to access the fqdn from the record set associated with it
  # because the private_dns_zone_configs and record_sets blocks expose lists, even if we only have one dns zone
  # and record set configured.
  # TODO(https://github.com/civiform/civiform/issues/8364): commenting postgres_private_link out for now as I
  # set up the private link network right now postgres server is protected by password, subnet, and firewall, 
  # which is enough for staging purposes.
  postgres_private_link = azurerm_private_endpoint.endpoint.private_dns_zone_configs[0].record_sets[0].fqdn
  generated_hostname    = "${var.application_name}-${random_pet.server.id}.azurewebsites.net"

  postgres_password_keyvault_id   = "postgres-password"
  app_secret_key_keyvault_id      = "app-secret-key"
  api_secret_salt_key_keyvault_id = "api-secret-salt"
  adfs_secret_keyvault_id         = "adfs-secret"
  aws_secret_access_token         = "aws-secret-access-token"
  aws_access_key_id               = "aws-access-key-id"

  app_settings = merge({
    WEBSITES_ENABLE_APP_SERVICE_STORAGE = false
    PORT                                = 9000

    DB_USERNAME    = "${azurerm_postgresql_flexible_server.civiform.administrator_login}@${azurerm_postgresql_flexible_server.civiform.name}"
    DB_PASSWORD    = data.azurerm_key_vault_secret.postgres_password.value
    DB_JDBC_STRING = "jdbc:postgresql://${local.postgres_private_link}:5432/postgres?user=psqladmin&password=${azurerm_postgresql_flexible_server.civiform.administrator_password}&sslmode=require"

    STORAGE_SERVICE_NAME = "azure-blob"

    AZURE_STORAGE_ACCOUNT_NAME                  = azurerm_storage_account.files_storage_account.name
    AZURE_STORAGE_ACCOUNT_CONTAINER_NAME        = azurerm_storage_container.files_container.name
    AZURE_STORAGE_ACCOUNT_PUBLIC_CONTAINER_NAME = azurerm_storage_container.public_files_container.name

    AWS_ACCESS_KEY_ID     = var.email_provider == "aws-ses" ? data.azurerm_key_vault_secret.aws_access_key_id[0].value : ""
    AWS_SECRET_ACCESS_KEY = var.email_provider == "aws-ses" ? data.azurerm_key_vault_secret.aws_secret_access_token[0].value : ""

    SECRET_KEY = data.azurerm_key_vault_secret.app_secret_key.value

    ADFS_SECRET                  = data.azurerm_key_vault_secret.adfs_secret.value
    ADFS_CLIENT_ID               = data.azurerm_key_vault_secret.adfs_client_id.value
    ADFS_DISCOVERY_URI           = data.azurerm_key_vault_secret.adfs_discovery_uri.value
    APPLICANT_OIDC_CLIENT_SECRET = data.azurerm_key_vault_secret.adfs_secret.value
    APPLICANT_OIDC_DISCOVERY_URI = data.azurerm_key_vault_secret.adfs_discovery_uri.value
    APPLICANT_OIDC_CLIENT_ID     = data.azurerm_key_vault_secret.adfs_client_id.value

    # The values below are all defaulted to null. If SAML authentication is used, the values can be pulled from the
    # saml_keystore module
    LOGIN_RADIUS_KEYSTORE_NAME    = (var.saml_keystore_filename != null ? "/saml/${var.saml_keystore_filename}" : "")
    LOGIN_RADIUS_KEYSTORE_PASS    = var.saml_keystore_password
    LOGIN_RADIUS_PRIVATE_KEY_PASS = var.saml_private_key_password

    CIVIFORM_API_SECRET_SALT = data.azurerm_key_vault_secret.api_secret_salt_key.value

    # STAGING_HOSTNAME and BASE_URL are slot settings which are managed outside of Terraform
    # but we need to set an initial value for them here so that the ignore_changes block will work
    STAGING_HOSTNAME = "placeholder"
    BASE_URL         = "placeholder"

    # In HOCON, env variables set to the empty string are
    # kept as such (set to empty string, rather than undefined).
    # This allows for the default to include atallclaims and for
    # azure AD to not include that claim.
    ADFS_ADDITIONAL_SCOPES = ""
  }, var.civiform_server_environment_variables)
  adfs_client_id     = "adfs-client-id"
  adfs_discovery_uri = "adfs-discovery-uri"
}
