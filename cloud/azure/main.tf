# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "azurerm"
      version = ">=2.65"
    }
  }
  backend "azurerm" {}
  required_version = ">= 0.14.9"
}