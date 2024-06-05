provider "azurerm" {
  features {}
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
  profile = "aws-staging"
}
