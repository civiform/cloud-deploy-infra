provider "azurerm" {
  features {}
  # https://github.com/civiform/civiform/issues/8598
  subscription_id = "4ef4ae1b-c966-4ac4-9b7c-a837ea410821"
  skip_provider_registration = var.azure_skip_provider_registration
}