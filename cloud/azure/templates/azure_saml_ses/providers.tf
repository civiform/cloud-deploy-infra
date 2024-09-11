provider "azurerm" {
  features {}
  subscription_id = "4ef4ae1b-c966-4ac4-9b7c-a837ea410821"
}

provider "aws" {
  region = var.aws_region
}