# Fixture root for civiform_app. Two jobs:
#
# 1. bin/validate inits and validates it. The module call below exercises a
#    minimal configuration with placeholder inputs.
# 2. The *.tftest.hcl suite alongside it runs from here. Its run blocks plan
#    the module directly (see the `module` blocks in the suite), but init
#    happens in this directory, so this file's provider pin is what the suite
#    runs against. The module itself does not pin a provider.
#
# Pins the same provider version as the deployment roots. A bump has to land
# in every one of these at once; nothing checks that they agree:
#   cloud/aws/templates/aws_oidc/providers.tf
#   cloud/aws/modules/setup/main.tf
#   cloud/aws/modules/ecs_fargate_service/tests/external_lb/main.tf
#   cloud/aws/modules/civiform_app/tests/fixture/main.tf (this file)
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.66.0"
    }
  }
}

module "app" {
  source = "../../"

  app_prefix = "fixture"
  aws_region = "us-east-1"

  log_group_name         = "fixture-civiformlogs/"
  scraper_log_group_name = "fixture-civiform-scraper-logs/"

  secrets = [
    {
      name       = "DB_USERNAME"
      value_arn  = "arn:aws:secretsmanager:us-east-1:000000000000:secret:fixture-db-username-AAAAAA:v1"
      secret_arn = "arn:aws:secretsmanager:us-east-1:000000000000:secret:fixture-db-username-AAAAAA"
    },
  ]
  db_jdbc_string                  = "jdbc:postgresql://db.fixture.internal:5432/postgres?ssl=true&sslmode=require"
  file_storage_bucket_name        = "fixture-civiform-files-s3"
  file_storage_bucket_arn         = "arn:aws:s3:::fixture-civiform-files-s3"
  public_file_storage_bucket_name = "fixture-civiform-public-files-s3"
  kms_key_arns                    = ["arn:aws:kms:us-east-1:000000000000:key/00000000-0000-0000-0000-000000000000"]
}
