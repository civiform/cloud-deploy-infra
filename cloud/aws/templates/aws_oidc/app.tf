module "ecs_cluster" {
  source  = "cn-terraform/ecs-cluster/aws"
  version = "1.0.10"
  name    = "${var.app_prefix}-civiform"
  tags = {
    Name = "${var.app_prefix} Civiform ECS Cluster"
    Type = "Civiform ECS Cluster"
  }
}

# TODO: reconcile with other logs bucket. We should only have one.
module "aws_cw_logs" {
  source    = "cn-terraform/cloudwatch-logs/aws"
  version   = "1.0.12"
  logs_path = "${var.app_prefix}-civiformlogs/"
  tags = {
    Name = "${var.app_prefix} Civiform Cloud Watch Logs"
    Type = "Civiform Cloud Watch Logs"
  }
}

module "aws_scraper_logs" {
  source    = "cn-terraform/cloudwatch-logs/aws"
  version   = "1.0.12"
  logs_path = "${var.app_prefix}-civiform-scraper-logs/"
  tags = {
    Name = "${var.app_prefix} Scraper Logs"
    Type = "Scraper Logs"
  }
}

module "civiform_server_container_def" {
  source  = "cloudposse/ecs-container-definition/aws"
  version = "0.60.0"

  container_name               = "${var.app_prefix}-civiform"
  container_image              = "${var.civiform_image_repo}:${var.image_tag}"
  container_memory             = 4096
  container_memory_reservation = 2048

  secrets = [
    {
      name      = "DB_USERNAME"
      valueFrom = aws_secretsmanager_secret_version.postgres_username_secret_version.arn
    },
    {
      name      = "DB_PASSWORD"
      valueFrom = aws_secretsmanager_secret_version.postgres_password_secret_version.arn
    },
    {
      name      = "SECRET_KEY"
      valueFrom = aws_secretsmanager_secret_version.app_secret_key_secret_version.arn
    },
    {
      name      = "CIVIFORM_API_SECRET_SALT"
      valueFrom = aws_secretsmanager_secret_version.api_secret_salt_secret_version.arn
    },
    {
      name      = "ADFS_SECRET"
      valueFrom = aws_secretsmanager_secret_version.adfs_secret_secret_version.arn
    },
    {
      name      = "ADFS_CLIENT_ID"
      valueFrom = aws_secretsmanager_secret_version.adfs_client_id_secret_version.arn
    },
    {
      name      = "APPLICANT_OIDC_CLIENT_ID"
      valueFrom = aws_secretsmanager_secret_version.applicant_oidc_client_id_secret_version.arn
    },
    {
      name      = "APPLICANT_OIDC_CLIENT_SECRET"
      valueFrom = aws_secretsmanager_secret_version.applicant_oidc_client_secret_secret_version.arn
    },
    {
      name      = "ADMIN_OIDC_CLIENT_ID"
      valueFrom = aws_secretsmanager_secret_version.admin_oidc_client_id_secret_version.arn
    },
    {
      name      = "ADMIN_OIDC_CLIENT_SECRET"
      valueFrom = aws_secretsmanager_secret_version.admin_oidc_client_secret_secret_version.arn
    }
  ]

  map_environment = merge({
    PORT = var.port

    DB_JDBC_STRING = "jdbc:postgresql://${aws_db_instance.civiform.address}:${aws_db_instance.civiform.port}/postgres?ssl=true&sslmode=require"

    STORAGE_SERVICE_NAME = "s3"
    AWS_S3_BUCKET_NAME   = aws_s3_bucket.civiform_files_s3.id

    CIVIFORM_VERSION                        = var.image_tag
    SHOW_CIVIFORM_IMAGE_TAG_ON_LANDING_PAGE = var.show_civiform_image_tag_on_landing_page

    WHITELABEL_CIVIC_ENTITY_SHORT_NAME = var.civic_entity_short_name
    WHITELABEL_CIVIC_ENTITY_FULL_NAME  = var.civic_entity_full_name
    WHITELABEL_LOGO_WITH_NAME_URL      = var.civic_entity_logo_with_name_url

    SUPPORT_EMAIL_ADDRESS = var.civic_entity_support_email_address
    AWS_SES_SENDER        = var.sender_email_address

    STAGING_ADMIN_LIST                    = var.staging_program_admin_notification_mailing_list
    STAGING_TI_LIST                       = var.staging_ti_notification_mailing_list
    STAGING_APPLICANT_LIST                = var.staging_applicant_notification_mailing_list
    STAGING_ADD_NOINDEX_META_TAG          = var.staging_add_noindex_meta_tag
    STAGING_DISABLE_DEMO_MODE_LOGINS      = var.staging_disable_demo_mode_logins
    STAGING_DISABLE_APPLICANT_GUEST_LOGIN = var.staging_disable_applicant_guest_login

    APPLICANT_OIDC_PROVIDER_LOGOUT            = var.applicant_oidc_provider_logout
    APPLICANT_OIDC_OVERRIDE_LOGOUT_URL        = var.applicant_oidc_override_logout_url
    APPLICANT_OIDC_POST_LOGOUT_REDIRECT_PARAM = var.applicant_oidc_post_logout_redirect_param
    APPLICANT_OIDC_LOGOUT_CLIENT_PARAM        = var.applicant_oidc_logout_client_param

    CIVIFORM_ADMIN_REPORTING_UI_ENABLED          = var.feature_flag_reporting_enabled
    CIVIFORM_APPLICATION_STATUS_TRACKING_ENABLED = var.feature_flag_status_tracking_enabled

    # Add variables that are also listed in env-var-docs.json in the civiform repository below this line.

    # TODO: Remove variables below when auto generation via env-var-docs is fully enabled to avoid 
    # duplicates in the civiform_server_environment_variables map. 
    STAGING_HOSTNAME                     = var.staging_hostname
    BASE_URL                             = var.base_url != "" ? var.base_url : "https://${var.custom_hostname}"
    CLIENT_IP_TYPE                       = "FORWARDED"
    CIVIFORM_TIME_ZONE_ID                = var.civiform_time_zone_id
    AWS_REGION                           = var.aws_region
    ADFS_ADDITIONAL_SCOPES               = var.adfs_additional_scopes
    AD_GROUPS_ATTRIBUTE_NAME             = var.ad_groups_attribute_name

    BYPASS_LOGIN_LANGUAGE_SCREENS          = var.bypass_login_language_screens
    ALLOW_CIVIFORM_ADMIN_ACCESS_PROGRAMS   = var.allow_civiform_admin_access_programs
    PROGRAM_ELIGIBILITY_CONDITIONS_ENABLED = var.program_eligibility_conditions_enabled
    INTAKE_FORM_ENABLED                    = var.intake_form_enabled
    NONGATED_ELIGIBILITY_ENABLED           = var.nongated_eligibility_enabled
    PUBLISH_SINGLE_PROGRAM_ENABLED         = var.publish_single_program_enabled

    COMMON_INTAKE_MORE_RESOURCES_LINK_TEXT = var.common_intake_more_resources_link_text
    COMMON_INTAKE_MORE_RESOURCES_LINK_HREF = var.common_intake_more_resources_link_href

    ESRI_ADDRESS_CORRECTION_ENABLED  = var.esri_address_correction_enabled
    ESRI_FIND_ADDRESS_CANDIDATES_URL = var.esri_find_address_candidate_url

    CIVIFORM_API_KEYS_BAN_GLOBAL_SUBNET = var.civiform_api_keys_ban_global_subnet
    CIVIFORM_SERVER_METRICS_ENABLED     = var.civiform_server_metrics_enabled
    FEATURE_FLAG_OVERRIDES_ENABLED      = var.feature_flag_overrides_enabled
  }, var.civiform_server_environment_variables)

  port_mappings = [
    {
      containerPort = var.port
      hostPort      = var.port
      protocol      = "tcp"
    },
    {
      containerPort = 443
      hostPort      = 443
      protocol      = "tcp"
    },
  ]

  healthcheck = {
    command     = ["CMD-SHELL", "wget --quiet http://127.0.0.1:${var.port}/playIndex --output-document - > /dev/null 2>&1"]
    interval    = 10
    timeout     = 11
    retries     = 5
    startPeriod = 10
  }

  log_configuration = {
    logDriver = "awslogs"
    options = {
      "awslogs-region"        = var.aws_region
      "awslogs-stream-prefix" = "ecs"
      "awslogs-group"         = module.aws_cw_logs.logs_path
      "awslogs-create-group"  = "true"
      # Use https://docs.docker.com/config/containers/logging/awslogs/#awslogs-multiline-pattern
      # Logs are streamed via container's stdout. Each line is considered a
      # separate log messsage. To collect stacktraces, which take multiple line,
      # to a single event we consider all lines which start with a whitespace character to be
      # part of the previous line and not a standalone event.
      "awslogs-multiline-pattern" = "^[^\\s]"
    }
    secretOptions = null
  }
}

module "civiform_metrics_scraper_container_def" {
  source  = "cloudposse/ecs-container-definition/aws"
  version = "0.60.0"

  container_name               = "${var.app_prefix}-metrics-scraper"
  container_image              = var.scraper_image
  container_memory             = 2048
  container_memory_reservation = 1024

  map_environment = {
    PROMETHEUS_WRITE_ENDPOINT = var.monitoring_stack_enabled ? "${aws_prometheus_workspace.metrics[0].prometheus_endpoint}api/v1/remote_write" : ""
    AWS_REGION                = var.aws_region
  }

  log_configuration = {
    logDriver = "awslogs"
    options = {
      "awslogs-region"        = var.aws_region
      "awslogs-stream-prefix" = "ecs"
      "awslogs-group"         = module.aws_scraper_logs.logs_path
      "awslogs-create-group"  = "true"
      # Use https://docs.docker.com/config/containers/logging/awslogs/#awslogs-multiline-pattern
      # Logs are streamed via container's stdout. Each line is considered a
      # separate log messsage. To collect stacktraces, which take multiple line,
      # to a single event we consider all lines which start with a whitespace character to be
      # part of the previous line and not a standalone event.
      "awslogs-multiline-pattern" = "^[^\\s]"
    }
    secretOptions = null
  }
}

locals {
  name_prefix = "${var.app_prefix}-civiform"

  tags = {
    Name = "${var.app_prefix} Civiform EC2 Task Definition"
    Type = "Civiform EC2 Task Definition"
  }

  civiform_ecs_task_execution_role_custom_policies = [
    jsonencode(
      {
        "Version" : "2012-10-17",
        "Statement" : [
          {
            "Effect" : "Allow",
            "Action" : [
              "secretsmanager:GetSecretValue"
            ],
            "Resource" : [
              aws_secretsmanager_secret.postgres_username_secret.arn,
              aws_secretsmanager_secret.postgres_password_secret.arn,
              aws_secretsmanager_secret.app_secret_key_secret.arn,
              aws_secretsmanager_secret.api_secret_salt_secret.arn,
              aws_secretsmanager_secret.adfs_secret_secret.arn,
              aws_secretsmanager_secret.adfs_client_id_secret.arn,
              aws_secretsmanager_secret.applicant_oidc_client_secret_secret.arn,
              aws_secretsmanager_secret.applicant_oidc_client_id_secret.arn,
              aws_secretsmanager_secret.admin_oidc_client_secret_secret.arn,
              aws_secretsmanager_secret.admin_oidc_client_id_secret.arn,
            ]
          },
          {
            "Effect" : "Allow",
            "Action" : [
              "kms:Encrypt",
              "kms:Decrypt",
              "kms:ReEncrypt*",
              "kms:GenerateDataKey*",
              "kms:DescribeKey"
            ],
            "Resource" : [aws_kms_key.civiform_kms_key.arn, aws_kms_key.file_storage_key.arn]
          },
          {
            "Effect" : "Allow",
            "Action" : [
              "s3:*"
            ],
            "Resource" : [
              aws_s3_bucket.civiform_files_s3.arn,
              "${aws_s3_bucket.civiform_files_s3.arn}/*",
            ]
          },
          {
            "Effect" : "Allow",
            "Action" : [
              "ses:SendEmail"
            ],
            "Resource" : "*"
          },
          {
            "Effect" : "Allow",
            "Action" : [
              "aps:RemoteWrite"
            ],
            "Resource" : "*"
          }
        ]
      }
    )
  ]
}

resource "aws_iam_role" "civiform_ecs_task_execution_role" {
  name               = "${local.name_prefix}-ecs-task-execution-role"
  assume_role_policy = <<JSON
    {
      "Version": "2012-10-17",
      "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "ecs-tasks.amazonaws.com"
            },
            "Action": "sts:AssumeRole",
            "Sid": ""
        }
      ]
    }
JSON
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "civiform_ecs_task_execution_role_policy_attach" {
  role       = aws_iam_role.civiform_ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_policy" "civiform_ecs_task_execution_role_custom_policy" {
  count       = length(local.civiform_ecs_task_execution_role_custom_policies)
  name        = "${local.name_prefix}-ecs-task-execution-role-custom-policy-${count.index}"
  description = "A custom policy for ${local.name_prefix}-ecs-task-execution-role IAM Role"
  policy      = local.civiform_ecs_task_execution_role_custom_policies[count.index]
  tags        = local.tags
}

resource "aws_iam_role_policy_attachment" "civiform_ecs_task_execution_role_custom_policy" {
  count      = length(local.civiform_ecs_task_execution_role_custom_policies)
  role       = aws_iam_role.civiform_ecs_task_execution_role.name
  policy_arn = aws_iam_policy.civiform_ecs_task_execution_role_custom_policy[count.index].arn
}

resource "aws_ecs_task_definition" "civiform_with_monitoring" {
  family = "${local.name_prefix}-civiform-with-monitoring-td"

  cpu    = var.ecs_task_cpu
  memory = var.ecs_task_memory

  container_definitions = jsonencode([
    module.civiform_server_container_def.json_map_object,
    module.civiform_metrics_scraper_container_def.json_map_object
  ])

  task_role_arn            = aws_iam_role.civiform_ecs_task_execution_role.arn
  execution_role_arn       = aws_iam_role.civiform_ecs_task_execution_role.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  tags                     = local.tags
}

resource "aws_ecs_task_definition" "civiform_only" {
  family = "${local.name_prefix}-civiform-only-td"

  cpu    = var.ecs_task_cpu
  memory = var.ecs_task_memory

  container_definitions = jsonencode([module.civiform_server_container_def.json_map_object])

  task_role_arn            = aws_iam_role.civiform_ecs_task_execution_role.arn
  execution_role_arn       = aws_iam_role.civiform_ecs_task_execution_role.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  tags                     = local.tags
}

module "ecs_fargate_service" {
  source                    = "../../modules/ecs_fargate_service"
  app_prefix                = var.app_prefix
  desired_count             = var.fargate_desired_task_count
  default_certificate_arn   = var.ssl_certificate_arn
  ssl_policy                = "ELBSecurityPolicy-FS-1-2-Res-2020-10"
  vpc_id                    = module.vpc.vpc_id
  task_definition_arn       = var.monitoring_stack_enabled ? aws_ecs_task_definition.civiform_with_monitoring.arn : aws_ecs_task_definition.civiform_only.arn
  container_name            = "${var.app_prefix}-civiform"
  ecs_cluster_name          = module.ecs_cluster.aws_ecs_cluster_cluster_name
  ecs_cluster_arn           = module.ecs_cluster.aws_ecs_cluster_cluster_arn
  private_subnets           = module.vpc.private_subnets
  public_subnets            = module.vpc.public_subnets
  max_cpu_threshold         = var.ecs_max_cpu_threshold
  min_cpu_threshold         = var.ecs_min_cpu_threshold
  max_cpu_evaluation_period = var.ecs_max_cpu_evaluation_period
  min_cpu_evaluation_period = var.ecs_min_cpu_evaluation_period
  max_cpu_period            = var.ecs_max_cpu_period
  min_cpu_period            = var.ecs_min_cpu_period
  scale_target_max_capacity = var.ecs_scale_target_max_capacity
  scale_target_min_capacity = var.ecs_scale_target_min_capacity
  https_target_port         = var.port

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
