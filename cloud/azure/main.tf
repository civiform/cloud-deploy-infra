# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "azurerm"
      version = ">=3.98"
    }
    random = {}
  }
  backend "azurerm" {}
  required_version = ">= 1.1.9"
}
provider "azurerm" {
  features {}
  version = ">=2"
}
