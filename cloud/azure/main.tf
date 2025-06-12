# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "azurerm"
      version = "4.33.0"
    }
    random = {}
  }
  backend "azurerm" {}
  required_version = ">= 0.14.9"
}

provider "azurerm" {
  features {}

  skip_provider_registration = var.azure_skip_provider_registration
}
