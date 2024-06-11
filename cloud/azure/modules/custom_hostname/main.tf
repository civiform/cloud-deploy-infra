data "azurerm_dns_zone" "dns" {
  name                = var.custom_hostname
  resource_group_name = var.resource_group_name
}

resource "azurerm_dns_txt_record" "txt" {
  name                = "asuid.${azurerm_dns_zone.dns.name}"
  zone_name           = data.azurerm_dns_zone.dns.name
  resource_group_name = data.azurerm_dns_zone.dns.resource_group_name
  ttl                 = 300
  record {
    value = var.custom_domain_verification_id
  }
}

resource "azurerm_app_service_custom_hostname_binding" "custom_domain_binding" {
  hostname            = var.custom_hostname
  app_service_name    = var.app_service_name
  resource_group_name = var.resource_group_name
  depends_on          = [azurerm_dns_txt_record.txt]
  lifecycle {
    ignore_changes = [ssl_state, thumbprint]
  }
}

resource "azurerm_app_service_managed_certificate" "cert" {
  custom_hostname_binding_id = azurerm_app_service_custom_hostname_binding.custom_domain_binding.id
}

resource "azurerm_app_service_certificate_binding" "cert_binding" {
  hostname_binding_id = azurerm_app_service_custom_hostname_binding.custom_domain_binding.id
  certificate_id      = azurerm_app_service_managed_certificate.cert.id
  ssl_state           = "IpBasedEnabled"
}
