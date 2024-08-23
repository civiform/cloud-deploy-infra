resource "random_pet" "server" {}

resource "random_string" "resource_code" {
  length  = 5
  special = false
  upper   = false
}

data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

resource "azurerm_virtual_network" "civiform_vnet" {
  name                = "civiform-vnet"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  address_space       = var.vnet_address_space
}

data "azurerm_key_vault_secret" "adfs_client_id" {
  name         = local.adfs_client_id
  key_vault_id = data.azurerm_key_vault.civiform_key_vault.id
}

data "azurerm_key_vault_secret" "adfs_discovery_uri" {
  name         = local.adfs_discovery_uri
  key_vault_id = data.azurerm_key_vault.civiform_key_vault.id
}

resource "azurerm_data_protection_backup_vault" "backup_vault" {
  name                = "backup-vault"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  datastore_type      = "VaultStore"
  redundancy          = "LocallyRedundant"
  identity {
    type = "SystemAssigned"
  }
}


resource "azurerm_subnet" "server_subnet" {
  name                 = "server-subnet"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.civiform_vnet.name
  address_prefixes     = var.subnet_address_prefixes

  delegation {
    name = "app-service-delegation"

    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_service_plan" "plan" {
  name                = "${data.azurerm_resource_group.rg.name}-plan"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = var.app_sku
}

resource "azurerm_linux_web_app" "civiform_app" {
  name                = "${var.application_name}-${random_pet.server.id}"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.plan.id
  app_settings        = local.app_settings

  site_config {
    application_stack {
      docker_image_name   = var.image_tag
      docker_registry_url = "https://index.docker.io"
    }
  }

  connection_string {
    name  = "postgres-database"
    type  = "PostgreSQL"
    value = local.app_settings.DB_JDBC_STRING
  }

  # We will only mount this storage container if SAML authentication is being used
  dynamic "storage_account" {
    for_each = var.civiform_applicant_auth_protocol == "saml" ? [1] : []

    content {
      name         = "civiform-saml-keystore"
      type         = "AzureBlob"
      account_name = var.saml_keystore_storage_account_name
      share_name   = var.saml_keystore_storage_container_name
      access_key   = var.saml_keystore_storage_access_key
      mount_path   = "/saml"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  logs {
    http_logs {
      file_system {
        retention_in_days = 1
        retention_in_mb   = 35
      }
    }
  }

  lifecycle {
    ignore_changes = [
      app_settings["STAGING_HOSTNAME"],
      app_settings["BASE_URL"],
    ]
  }
}

# Configure private link
resource "azurerm_subnet" "postgres_subnet" {
  name                 = "postgres_subnet"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.civiform_vnet.name
  address_prefixes     = var.postgres_subnet_address_prefixes
  service_endpoints    = ["Microsoft.Storage"]
  delegation {
    name = "delegation"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/publicIPAddresses/read",
        "Microsoft.Network/networkinterfaces/*",
        "Microsoft.Network/virtualNetworks/subnets/action",
        "Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_private_dns_zone" "privatedns" {
  name                = "civiform.postgres.database.azure.com"
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "networklink" {
  name                  = "civiformvnetzone.com"
  private_dns_zone_name = azurerm_private_dns_zone.privatedns.name
  virtual_network_id    = azurerm_virtual_network.civiform_vnet.id
  resource_group_name   = data.azurerm_resource_group.rg.name
  depends_on            = [azurerm_subnet.postgres_subnet]
}

resource "azurerm_postgresql_flexible_server" "civiform" {
  name                          = random_pet.server.id
  location                      = data.azurerm_resource_group.rg.location
  resource_group_name           = data.azurerm_resource_group.rg.name
  administrator_login           = var.postgres_admin_login
  administrator_password        = data.azurerm_key_vault_secret.postgres_password.value
  sku_name                      = var.postgres_sku_name
  version                       = "15"
  storage_mb                    = var.postgres_storage_mb
  # public_network_access_enabled = false
  private_dns_zone_id           = azurerm_private_dns_zone.privatedns.id
  # delegated_subnet_id           = azurerm_subnet.postgres_subnet.id
  # depends_on                    = [azurerm_private_dns_zone_virtual_network_link.networklink]

  lifecycle {
    ignore_changes = [
      zone
    ]
  }
}

resource "azurerm_postgresql_flexible_server_database" "civiform" {
  name      = "civiform"
  server_id = azurerm_postgresql_flexible_server.civiform.id
  charset   = "utf8"
  collation = "en_US.utf8"
}

resource "azurerm_postgresql_flexible_server_configuration" "extensions" {
  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.civiform.id
  value     = "PG_TRGM,BTREE_GIN"
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "firewall" {
  name             = "fw"
  server_id        = azurerm_postgresql_flexible_server.civiform.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

module "bastion" {
  source = "../bastion"

  resource_group_name      = data.azurerm_resource_group.rg.name
  resource_group_location  = data.azurerm_resource_group.rg.location
  bastion_address_prefixes = var.bastion_address_prefixes
  vnet_name                = azurerm_virtual_network.civiform_vnet.name
}
