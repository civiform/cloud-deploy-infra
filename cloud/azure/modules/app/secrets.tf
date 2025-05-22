data "azurerm_key_vault" "civiform_key_vault" {
  name                = var.key_vault_name
  resource_group_name = data.azurerm_resource_group.rg.name
}

data "azurerm_key_vault_secret" "postgres_password" {
  name         = local.postgres_password_keyvault_id
  key_vault_id = data.azurerm_key_vault.civiform_key_vault.id
}

data "azurerm_key_vault_secret" "app_secret_key" {
  name         = local.app_secret_key_keyvault_id
  key_vault_id = data.azurerm_key_vault.civiform_key_vault.id
}

data "azurerm_key_vault_secret" "api_secret_salt_key" {
  name         = local.api_secret_salt_key_keyvault_id
  key_vault_id = data.azurerm_key_vault.civiform_key_vault.id
}

data "azurerm_key_vault_secret" "adfs_secret" {
  name         = local.adfs_secret_keyvault_id
  key_vault_id = data.azurerm_key_vault.civiform_key_vault.id
}

data "azurerm_key_vault_secret" "applicant_oidc_client_id" {
  name         = local.applicant_oidc_client_id
  key_vault_id = data.azurerm_key_vault.civiform_key_vault.id
}

data "azurerm_key_vault_secret" "applicant_oidc_client_secret" {
  name         = local.applicant_oidc_client_secret
  key_vault_id = data.azurerm_key_vault.civiform_key_vault.id
}

data "azurerm_key_vault_secret" "applicant_oidc_discovery_uri" {
  name         = local.applicant_oidc_discovery_uri
  key_vault_id = data.azurerm_key_vault.civiform_key_vault.id
}
