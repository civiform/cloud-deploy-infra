provider "azurerm" {
  features {}
  # https://github.com/civiform/civiform/issues/8598
  skip_provider_registration = var.azure_skip_provider_registration
}
