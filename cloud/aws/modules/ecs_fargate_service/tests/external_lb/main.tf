# Fixture root for ecs_fargate_service. Two jobs:
#
# 1. bin/validate inits and validates it. The module call below exercises the
#    external-load-balancer path, which no deployment template currently uses.
# 2. The *.tftest.hcl suite alongside it runs from here. Its run blocks plan
#    the module directly (see the `module` blocks in the suite), but init
#    happens in this directory, so this file's provider pin is what the suite
#    runs against. The module itself does not pin a provider.
#
# Pins the same provider version as the deployment roots. A bump has to land
# in every one of these at once; nothing checks that they agree:
#   cloud/aws/templates/aws_oidc/providers.tf
#   cloud/aws/modules/setup/main.tf
#   cloud/aws/modules/ecs_fargate_service/tests/external_lb/main.tf (this file)
#   cloud/aws/modules/civiform_app/tests/fixture/main.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.66.0"
    }
  }
}

module "service_with_external_lb" {
  source = "../../"

  create_load_balancer          = false
  existing_lb_security_group_id = "sg-00000000000000000"

  app_prefix          = "fixture"
  vpc_id              = "vpc-00000000000000000"
  private_subnets     = ["subnet-00000000000000000"]
  ecs_cluster_arn     = "arn:aws:ecs:us-east-1:000000000000:cluster/fixture"
  ecs_cluster_name    = "fixture"
  task_definition_arn = "arn:aws:ecs:us-east-1:000000000000:task-definition/fixture:1"
  container_name      = "fixture-civiform"
}
