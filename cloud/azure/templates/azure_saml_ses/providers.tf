provider "azurerm" {
  features {}
  skip_provider_registration = true
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-2"
  profile = "aws-staging"
}
