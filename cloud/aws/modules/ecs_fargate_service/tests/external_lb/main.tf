# Validation-only fixture. Exercises the external-load-balancer path of
# ecs_fargate_service, which no deployment template currently uses. Pins the
# same provider version as the aws_oidc root so validate reflects a real deploy.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.14.0"
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
