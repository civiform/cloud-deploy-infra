output "app_service_default_hostname" {
  value = "https://${azurerm_linux_web_app.civiform_app.default_hostname}"
}

output "app_service_name" {
  value = azurerm_linux_web_app.civiform_app.name
}

output "resource_group_name" {
  value = data.azurerm_resource_group.rg.name
}

output "custom_domain_verification_id" {
  value = azurerm_linux_web_app.civiform_app.custom_domain_verification_id
}

output "debug_civiform_server_environment_variables" {
  value = var.civiform_server_environment_variables
}
output "debug_app_settings" {
  value = local.app_settings
}
