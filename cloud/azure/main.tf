# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "azurerm"
      version = "4.81.0"
    }
    random = {}
  }
  backend "azurerm" {}
  required_version = ">= 1.16.0"
}

provider "azurerm" {
  features {}

  skip_provider_registration = var.azure_skip_provider_registration
}
