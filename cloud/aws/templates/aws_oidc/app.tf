module "ecs_cluster" {
  source  = "cn-terraform/ecs-cluster/aws"
  version = "1.0.12"
  name    = "${var.app_prefix}-civiform"
  tags = {
    Name = "${var.app_prefix} Civiform ECS Cluster"
    Type = "Civiform ECS Cluster"
  }
}

# TODO: reconcile with other logs bucket. We should only have one.
module "aws_cw_logs" {
  source    = "cn-terraform/cloudwatch-logs/aws"
  version   = "1.0.13"
  logs_path = "${var.app_prefix}-civiformlogs/"
  tags = {
    Name = "${var.app_prefix} Civiform Cloud Watch Logs"
    Type = "Civiform Cloud Watch Logs"
  }
}

module "aws_scraper_logs" {
  source    = "cn-terraform/cloudwatch-logs/aws"
  version   = "1.0.13"
  logs_path = "${var.app_prefix}-civiform-scraper-logs/"
  tags = {
    Name = "${var.app_prefix} Scraper Logs"
    Type = "Scraper Logs"
  }
}

locals {
  # Retained for alarms.tf; the app's own resource names are now built inside
  # the civiform_app module from the same app_prefix.
  name_prefix = "${var.app_prefix}-civiform"

  # Single source of truth for the secrets the CiviForm server reads. The
  # civiform_app module derives both the container definition's secrets array
  # and the task execution role's secretsmanager:GetSecretValue statement from
  # this list, so the two cannot drift.
  #
  # Order is significant: it fixes the order of the container definition's
  # secrets array, and reordering forces a new task definition revision and a
  # rolling redeploy. The "name" key must match the environment variable used
  # within the CiviForm application.
  civiform_secrets = [
    {
      name       = "DB_USERNAME"
      value_arn  = aws_secretsmanager_secret_version.postgres_username_secret_version.arn
      secret_arn = aws_secretsmanager_secret.postgres_username_secret.arn
    },
    {
      name       = "DB_PASSWORD"
      value_arn  = aws_secretsmanager_secret_version.postgres_password_secret_version.arn
      secret_arn = aws_secretsmanager_secret.postgres_password_secret.arn
    },
    {
      name       = "SECRET_KEY"
      value_arn  = aws_secretsmanager_secret_version.app_secret_key_secret_version.arn
      secret_arn = aws_secretsmanager_secret.app_secret_key_secret.arn
    },
    {
      name       = "CIVIFORM_API_SECRET_SALT"
      value_arn  = aws_secretsmanager_secret_version.api_secret_salt_secret_version.arn
      secret_arn = aws_secretsmanager_secret.api_secret_salt_secret.arn
    },
    {
      name       = "ADFS_SECRET"
      value_arn  = aws_secretsmanager_secret_version.adfs_secret_secret_version.arn
      secret_arn = aws_secretsmanager_secret.adfs_secret_secret.arn
    },
    {
      name       = "ADFS_CLIENT_ID"
      value_arn  = aws_secretsmanager_secret_version.adfs_client_id_secret_version.arn
      secret_arn = aws_secretsmanager_secret.adfs_client_id_secret.arn
    },
    {
      name       = "APPLICANT_OIDC_CLIENT_ID"
      value_arn  = aws_secretsmanager_secret_version.applicant_oidc_client_id_secret_version.arn
      secret_arn = aws_secretsmanager_secret.applicant_oidc_client_id_secret.arn
    },
    {
      name       = "APPLICANT_OIDC_CLIENT_SECRET"
      value_arn  = aws_secretsmanager_secret_version.applicant_oidc_client_secret_secret_version.arn
      secret_arn = aws_secretsmanager_secret.applicant_oidc_client_secret_secret.arn
    },
    {
      name       = "ADMIN_OIDC_CLIENT_ID"
      value_arn  = aws_secretsmanager_secret_version.admin_oidc_client_id_secret_version.arn
      secret_arn = aws_secretsmanager_secret.admin_oidc_client_id_secret.arn
    },
    {
      name       = "ADMIN_OIDC_CLIENT_SECRET"
      value_arn  = aws_secretsmanager_secret_version.admin_oidc_client_secret_secret_version.arn
      secret_arn = aws_secretsmanager_secret.admin_oidc_client_secret_secret.arn
    },
    {
      name       = "ESRI_ARCGIS_API_TOKEN"
      value_arn  = aws_secretsmanager_secret_version.esri_arcgis_api_token_secret_version.arn
      secret_arn = aws_secretsmanager_secret.esri_arcgis_api_token_secret.arn
    }
  ]
}

module "civiform_app" {
  source = "../../modules/civiform_app"

  app_prefix = var.app_prefix
  aws_region = var.aws_region

  civiform_image_repo                     = var.civiform_image_repo
  image_tag                               = var.image_tag
  port                                    = var.port
  ecs_server_container_memory             = var.ecs_server_container_memory
  ecs_server_container_memory_reservation = var.ecs_server_container_memory_reservation
  civiform_server_environment_variables   = var.civiform_server_environment_variables
  log_group_name                          = module.aws_cw_logs.logs_path

  scraper_image                                    = var.scraper_image
  ecs_metrics_scraper_container_memory             = var.ecs_metrics_scraper_container_memory
  ecs_metrics_scraper_container_memory_reservation = var.ecs_metrics_scraper_container_memory_reservation
  prometheus_remote_write_endpoint                 = var.monitoring_stack_enabled ? "${aws_prometheus_workspace.metrics[0].prometheus_endpoint}api/v1/remote_write" : ""
  scraper_log_group_name                           = module.aws_scraper_logs.logs_path

  ecs_task_cpu    = var.ecs_task_cpu
  ecs_task_memory = var.ecs_task_memory

  secrets                         = local.civiform_secrets
  db_jdbc_string                  = "jdbc:postgresql://${aws_db_instance.civiform.address}:${aws_db_instance.civiform.port}/postgres?ssl=true&sslmode=require"
  file_storage_bucket_name        = aws_s3_bucket.civiform_files_s3.id
  file_storage_bucket_arn         = aws_s3_bucket.civiform_files_s3.arn
  public_file_storage_bucket_name = aws_s3_bucket.civiform_public_files_s3.id
  kms_key_arns                    = [aws_kms_key.civiform_kms_key.arn, aws_kms_key.file_storage_key.arn]
}

# These resources used to be declared directly in this file. The moves below
# preserve their state addresses; without them every existing deployment would
# destroy and recreate its task execution role and both task definitions.
#
# The two cloudposse container definition modules that also moved need no
# `moved` block: they declare no resources and hold no state.
moved {
  from = aws_iam_role.civiform_ecs_task_execution_role
  to   = module.civiform_app.aws_iam_role.civiform_ecs_task_execution_role
}

moved {
  from = aws_iam_role_policy_attachment.civiform_ecs_task_execution_role_policy_attach
  to   = module.civiform_app.aws_iam_role_policy_attachment.civiform_ecs_task_execution_role_policy_attach
}

moved {
  from = aws_iam_policy.civiform_ecs_task_execution_role_custom_policy
  to   = module.civiform_app.aws_iam_policy.civiform_ecs_task_execution_role_custom_policy
}

moved {
  from = aws_iam_role_policy_attachment.civiform_ecs_task_execution_role_custom_policy
  to   = module.civiform_app.aws_iam_role_policy_attachment.civiform_ecs_task_execution_role_custom_policy
}

moved {
  from = aws_ecs_task_definition.civiform_with_monitoring
  to   = module.civiform_app.aws_ecs_task_definition.civiform_with_monitoring
}

moved {
  from = aws_ecs_task_definition.civiform_only
  to   = module.civiform_app.aws_ecs_task_definition.civiform_only
}

module "ecs_fargate_service" {
  source                    = "../../modules/ecs_fargate_service"
  app_prefix                = var.app_prefix
  desired_count             = var.fargate_desired_task_count
  default_certificate_arn   = var.ssl_certificate_arn
  ssl_policy                = "ELBSecurityPolicy-FS-1-2-Res-2020-10"
  vpc_id                    = local.vpc_id
  task_definition_arn       = var.monitoring_stack_enabled ? module.civiform_app.civiform_with_monitoring_task_definition_arn : module.civiform_app.civiform_only_task_definition_arn
  container_name            = module.civiform_app.server_container_name
  ecs_cluster_name          = module.ecs_cluster.aws_ecs_cluster_cluster_name
  ecs_cluster_arn           = module.ecs_cluster.aws_ecs_cluster_cluster_arn
  private_subnets           = local.vpc_private_subnet_ids
  public_subnets            = local.vpc_public_subnet_ids
  max_cpu_threshold         = var.ecs_max_cpu_threshold
  min_cpu_threshold         = var.ecs_min_cpu_threshold
  max_cpu_evaluation_period = var.ecs_max_cpu_evaluation_period
  min_cpu_evaluation_period = var.ecs_min_cpu_evaluation_period
  max_cpu_period            = var.ecs_max_cpu_period
  min_cpu_period            = var.ecs_min_cpu_period
  scale_target_max_capacity = var.ecs_scale_target_max_capacity
  scale_target_min_capacity = var.ecs_scale_target_min_capacity
  https_target_port         = var.port
  lb_internal               = local.enable_managed_vpc ? false : true
  lb_idle_timeout           = var.lb_idle_timeout
  lb_logging_enabled        = var.lb_logging_enabled
  extra_inbound_rule_cidr   = var.extra_inbound_rule_cidr
  ingress_sg_cidr           = var.ingress_sg_cidr
  enable_http_listener      = var.enable_http_listener
  sns_topic_arn             = length(aws_sns_topic.civiform_alert_topic) > 0 ? aws_sns_topic.civiform_alert_topic[0].arn : ""

  tags = {
    Name = "${var.app_prefix} Civiform Fargate Service"
    Type = "Civiform Fargate Service"
  }
}

resource "aws_lb_listener_rule" "block_external_traffic_to_metrics_rule" {
  listener_arn = module.ecs_fargate_service.https_listener_arn

  action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Forbidden"
      status_code  = "403"
    }
  }

  condition {
    path_pattern {
      values = ["/metrics"]
    }
  }
}

moved {
  from = aws_lb_listener_rule.block_external_traffic_to_metrics_rule[0]
  to   = aws_lb_listener_rule.block_external_traffic_to_metrics_rule
}
