# terraform {
#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       version = "5.78.0"
#     }
#   }
# }

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Group       = "setup-${var.app_prefix}"
      Environment = "${var.civiform_mode}"
      Service     = "Civiform Setup"
    }
  }

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
}
