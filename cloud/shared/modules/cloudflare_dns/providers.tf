terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
  backend "s3" {}
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
