# Primary managed identity role assignments:

resource "azurerm_role_assignment" "storage_blob_delegator" {
  scope                = azurerm_storage_account.files_storage_account.id
  role_definition_name = "Storage Blob Delegator"
  principal_id         = azurerm_linux_web_app.civiform_app.identity.0.principal_id
}

resource "azurerm_role_assignment" "key_vault_secrets_principal_user" {
  scope                = data.azurerm_key_vault.civiform_key_vault.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = azurerm_linux_web_app.civiform_app.identity.0.principal_id
}

resource "azurerm_role_assignment" "key_vault_secrets_staging_user" {
  scope                = data.azurerm_key_vault.civiform_key_vault.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = "f552a386-fd60-40bf-93a7-57c441bb0c99"
}

resource "azurerm_role_assignment" "storage_blob_data_contributor" {
  scope                = azurerm_storage_account.files_storage_account.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_web_app.civiform_app.identity.0.principal_id
}

# Grant the app the role of storage account contributor, as the app needs 
# to set its own CORS rules
resource "azurerm_role_assignment" "storage_account_contributor" {
  scope                = azurerm_storage_account.files_storage_account.id
  role_definition_name = "Storage Account Contributor"
  principal_id         = azurerm_linux_web_app.civiform_app.identity.0.principal_id
}


resource "azurerm_role_assignment" "storage_backup_contributor" {
  scope                = azurerm_storage_account.files_storage_account.id
  role_definition_name = "Storage Account Backup Contributor"
  principal_id         = azurerm_data_protection_backup_vault.backup_vault.identity[0].principal_id
}
