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
  version = "0.58.3"

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
    WHITELABEL_SMALL_LOGO_URL          = var.civic_entity_small_logo_url
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
    APPLICANT_OIDC_DISCOVERY_URI              = var.applicant_oidc_discovery_uri

    CIVIFORM_ADMIN_REPORTING_UI_ENABLED          = var.feature_flag_reporting_enabled
    CIVIFORM_APPLICATION_STATUS_TRACKING_ENABLED = var.feature_flag_status_tracking_enabled

    # Add variables that are also listed in env-var-docs.json in the civiform repository below this line.

    # TODO: Remove variables below when auto generation via env-var-docs is fully enabled to avoid 
    # duplicates in the civiform_server_environment_variables map. 
    STAGING_HOSTNAME                     = var.staging_hostname
    BASE_URL                             = var.base_url != "" ? var.base_url : "https://${var.custom_hostname}"
    CLIENT_IP_TYPE                       = "FORWARDED"
    CIVIFORM_TIME_ZONE_ID                = var.civiform_time_zone_id
    FAVICON_URL                          = var.favicon_url
    AWS_REGION                           = var.aws_region
    CIVIFORM_APPLICANT_IDP               = var.civiform_applicant_idp
    APPLICANT_OIDC_PROVIDER_NAME         = var.applicant_oidc_provider_name
    APPLICANT_OIDC_RESPONSE_MODE         = var.applicant_oidc_response_mode
    APPLICANT_OIDC_RESPONSE_TYPE         = var.applicant_oidc_response_type
    APPLICANT_OIDC_ADDITIONAL_SCOPES     = var.applicant_oidc_additional_scopes
    APPLICANT_OIDC_LOCALE_ATTRIBUTE      = var.applicant_oidc_locale_attribute
    APPLICANT_OIDC_EMAIL_ATTRIBUTE       = var.applicant_oidc_email_attribute
    APPLICANT_OIDC_FIRST_NAME_ATTRIBUTE  = var.applicant_oidc_first_name_attribute
    APPLICANT_OIDC_MIDDLE_NAME_ATTRIBUTE = var.applicant_oidc_middle_name_attribute
    APPLICANT_OIDC_LAST_NAME_ATTRIBUTE   = var.applicant_oidc_last_name_attribute
    ADFS_DISCOVERY_URI                   = var.adfs_discovery_uri
    ADFS_ADDITIONAL_SCOPES               = var.adfs_additional_scopes
    ADFS_GLOBAL_ADMIN_GROUP              = var.adfs_admin_group
    AD_GROUPS_ATTRIBUTE_NAME             = var.ad_groups_attribute_name

    BYPASS_LOGIN_LANGUAGE_SCREENS          = var.bypass_login_language_screens
    ALLOW_CIVIFORM_ADMIN_ACCESS_PROGRAMS   = var.allow_civiform_admin_access_programs
    PROGRAM_ELIGIBILITY_CONDITIONS_ENABLED = var.program_eligibility_conditions_enabled
    INTAKE_FORM_ENABLED                    = var.intake_form_enabled
    NONGATED_ELIGIBILITY_ENABLED           = var.nongated_eligibility_enabled
    PHONE_QUESTION_TYPE_ENABLED            = var.phone_question_type_enabled
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
  version = "0.58.3"

  container_name               = "${var.app_prefix}-metrics-scraper"
  container_image              = var.scraper_image
  container_memory             = 2048
  container_memory_reservation = 1024

  map_environment = {
    PROMETHEUS_WRITE_ENDPOINT = "${aws_prometheus_workspace.metrics.prometheus_endpoint}api/v1/remote_write"
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

resource "aws_ecs_task_definition" "td" {
  family = "${local.name_prefix}-td"

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

# This is a collection of resources that we used to rely on
# cn-terraform/ecs-fargate-service/aws to provide, but this module
# frequently broke us, so we include the necessary resources here instead.
#
# In places where we were not defining variables, the defaults from
# https://github.com/cn-terraform/terraform-aws-ecs-fargate-service/blob/a1c2ea9fddb0ce682d6dac2e9af6b615a994e494/variables.tf
# were used.

## ecs-fargate-service replacement

### ecs-alb replacement
#------------------------------------------------------------------------------
# S3 BUCKET - For access logs
#------------------------------------------------------------------------------
data "aws_elb_service_account" "default" {}

#------------------------------------------------------------------------------
# APPLICATION LOAD BALANCER
#------------------------------------------------------------------------------
resource "aws_lb" "lb" {
  name = substr("${local.name_prefix}-lb", 0, 31)

  internal                         = false
  load_balancer_type               = "application"
  drop_invalid_header_fields       = false
  subnets                          = module.vpc.public_subnets
  idle_timeout                     = 60
  enable_deletion_protection       = false
  enable_cross_zone_load_balancing = false
  enable_http2                     = true
  ip_address_type                  = "ipv4"
  security_groups                  = [aws_security_group.lb_access_sg.id]

  tags = {
    Name = "${local.name_prefix}-lb"
    Type = "Civiform Fargate Service"
  }
}

#------------------------------------------------------------------------------
# ACCESS CONTROL TO APPLICATION LOAD BALANCER
#------------------------------------------------------------------------------
resource "aws_security_group" "lb_access_sg" {
  name        = "${local.name_prefix}-lb-access-sg"
  description = "Controls access to the Load Balancer"
  vpc_id      = module.vpc.vpc_id
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${local.name_prefix}-lb-access-sg"
    Type = "Civiform Fargate Service"
  }
}

locals {
  http_ports = {
    default_http = {
      type          = "redirect"
      listener_port = 80
      port          = 443
      protocol      = "HTTPS"
      host          = "#{host}"
      path          = "/#{path}"
      query         = "#{query}"
      status_code   = "HTTP_301"
    }
  }
  https_ports = {
    default_http = {
      listener_port         = 443
      target_group_port     = var.port
      target_group_protocol = "HTTP"
    }
  }
}
resource "aws_security_group_rule" "ingress_through_http" {
  for_each          = local.http_ports
  security_group_id = aws_security_group.lb_access_sg.id
  type              = "ingress"
  from_port         = each.value.listener_port
  to_port           = each.value.listener_port
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  prefix_list_ids   = []
}

resource "aws_security_group_rule" "ingress_through_https" {
  for_each          = local.https_ports
  security_group_id = aws_security_group.lb_access_sg.id
  type              = "ingress"
  from_port         = each.value.listener_port
  to_port           = each.value.listener_port
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  prefix_list_ids   = []
}

#------------------------------------------------------------------------------
# AWS LOAD BALANCER - Target Groups
#------------------------------------------------------------------------------
resource "aws_lb_target_group" "lb_http_tgs" {
  for_each = {
    for name, config in local.http_ports : name => config
    if lookup(config, "type", "") == "" || lookup(config, "type", "") == "forward"
  }
  # Removed each.key from name, as it was often exceeding the 32 character limit, and
  # using app_prefix instead to cut down on the length.
  name                          = "${var.app_prefix}-http-${each.value.target_group_port}"
  port                          = each.value.target_group_port
  protocol                      = lookup(each.value, "target_group_protocol", "HTTP")
  vpc_id                        = module.vpc.vpc_id
  deregistration_delay          = 300
  slow_start                    = 0
  load_balancing_algorithm_type = "round_robin"

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = true
  }

  health_check {
    enabled             = true
    interval            = 10
    path                = "/playIndex"
    protocol            = lookup(each.value, "target_group_protocol", "HTTP")
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }
  target_type = "ip"
  tags = {
    Name = "${local.name_prefix}-http-${each.value.target_group_port}"
    Type = "Civiform Fargate Service"
  }
  lifecycle {
    create_before_destroy = true
  }
  depends_on = [aws_lb.lb]
}

resource "aws_lb_target_group" "lb_https_tgs" {
  for_each = {
    for name, config in local.https_ports : name => config
    if lookup(config, "type", "") == "" || lookup(config, "type", "") == "forward"
  }
  # Removed each.key from name, as it was often exceeding the 32 character limit, and
  # using app_prefix instead to cut down on the length.
  name                          = "${var.app_prefix}-https-${each.value.target_group_port}"
  port                          = each.value.target_group_port
  protocol                      = lookup(each.value, "target_group_protocol", "HTTPS")
  vpc_id                        = module.vpc.vpc_id
  deregistration_delay          = 300
  slow_start                    = 0
  load_balancing_algorithm_type = "round_robin"
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = true
  }
  health_check {
    enabled             = true
    interval            = 10
    path                = "/playIndex"
    protocol            = lookup(each.value, "target_group_protocol", "HTTPS")
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }
  target_type = "ip"
  tags = {
    Name = "${local.name_prefix}-https-${each.value.target_group_port}"
    Type = "Civiform Fargate Service"
  }
  lifecycle {
    create_before_destroy = true
  }
  depends_on = [aws_lb.lb]
}

#------------------------------------------------------------------------------
# AWS LOAD BALANCER - Listeners
#------------------------------------------------------------------------------
resource "aws_lb_listener" "lb_http_listeners" {
  for_each          = local.http_ports
  load_balancer_arn = aws_lb.lb.arn
  port              = each.value.listener_port
  protocol          = "HTTP"

  dynamic "default_action" {
    for_each = lookup(each.value, "type", "") == "redirect" ? [1] : []
    content {
      type = "redirect"

      redirect {
        host        = lookup(each.value, "host", "#{host}")
        path        = lookup(each.value, "path", "/#{path}")
        port        = lookup(each.value, "port", "#{port}")
        protocol    = lookup(each.value, "protocol", "#{protocol}")
        query       = lookup(each.value, "query", "#{query}")
        status_code = lookup(each.value, "status_code", "HTTP_301")
      }
    }
  }

  dynamic "default_action" {
    for_each = lookup(each.value, "type", "") == "fixed-response" ? [1] : []
    content {
      type = "fixed-response"

      fixed_response {
        content_type = lookup(each.value, "content_type", "text/plain")
        message_body = lookup(each.value, "message_body", "Fixed response content")
        status_code  = lookup(each.value, "status_code", "200")
      }
    }
  }

  # We fallback to using forward type action if type is not defined
  dynamic "default_action" {
    for_each = (lookup(each.value, "type", "") == "" || lookup(each.value, "type", "") == "forward") ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.lb_http_tgs[each.key].arn
      type             = "forward"
    }
  }

  tags = {
    Name = "${var.app_prefix} Civiform Fargate Service"
    Type = "Civiform Fargate Service"
  }
}

resource "aws_lb_listener" "lb_https_listeners" {
  for_each          = local.https_ports
  load_balancer_arn = aws_lb.lb.arn
  port              = each.value.listener_port
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-FS-1-2-Res-2020-10"
  certificate_arn   = var.ssl_certificate_arn

  dynamic "default_action" {
    for_each = lookup(each.value, "type", "") == "redirect" ? [1] : []
    content {
      type = "redirect"

      redirect {
        host        = lookup(each.value, "host", "#{host}")
        path        = lookup(each.value, "path", "/#{path}")
        port        = lookup(each.value, "port", "#{port}")
        protocol    = lookup(each.value, "protocol", "#{protocol}")
        query       = lookup(each.value, "query", "#{query}")
        status_code = lookup(each.value, "status_code", "HTTP_301")
      }
    }
  }

  dynamic "default_action" {
    for_each = lookup(each.value, "type", "") == "fixed-response" ? [1] : []
    content {
      type = "fixed-response"

      fixed_response {
        content_type = lookup(each.value, "content_type", "text/plain")
        message_body = lookup(each.value, "message_body", "Fixed response content")
        status_code  = lookup(each.value, "status_code", "200")
      }
    }
  }

  # We fallback to using forward type action if type is not defined
  dynamic "default_action" {
    for_each = (lookup(each.value, "type", "") == "" || lookup(each.value, "type", "") == "forward") ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.lb_https_tgs[each.key].arn
      type             = "forward"
    }
  }

  tags = {
    Name = "${var.app_prefix} Civiform Fargate Service"
    Type = "Civiform Fargate Service"
  }
}
### end ecs-alb replacement

#------------------------------------------------------------------------------
# AWS ECS SERVICE
#------------------------------------------------------------------------------
locals {
  lb_http_tgs_map_arn_port = zipmap(
    [for tg in aws_lb_target_group.lb_http_tgs : tg.arn],
    [for tg in aws_lb_target_group.lb_http_tgs : tostring(tg.port)]
  )

  lb_https_tgs_map_arn_port = zipmap(
    [for tg in aws_lb_target_group.lb_https_tgs : tg.arn],
    [for tg in aws_lb_target_group.lb_https_tgs : tostring(tg.port)]
  )

  lb_http_tgs_ports = [for tg in aws_lb_target_group.lb_http_tgs : tostring(tg.port)]

  lb_https_tgs_ports = [for tg in aws_lb_target_group.lb_https_tgs : tostring(tg.port)]
}
resource "aws_ecs_service" "service" {
  name = "${local.name_prefix}-service"
  # capacity_provider_strategy - (Optional) The capacity provider strategy to use for the service. Can be one or more. Defined below.
  cluster                            = module.ecs_cluster.aws_ecs_cluster_cluster_arn
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  desired_count                      = var.fargate_desired_task_count
  enable_ecs_managed_tags            = false
  enable_execute_command             = false
  health_check_grace_period_seconds  = 20
  launch_type                        = "FARGATE"
  force_new_deployment               = false

  dynamic "load_balancer" {
    for_each = local.lb_http_tgs_map_arn_port
    content {
      target_group_arn = load_balancer.key
      container_name   = local.name_prefix
      container_port   = load_balancer.value
    }
  }
  dynamic "load_balancer" {
    for_each = local.lb_https_tgs_map_arn_port
    content {
      target_group_arn = load_balancer.key
      container_name   = local.name_prefix
      container_port   = load_balancer.value
    }
  }
  network_configuration {

    security_groups  = [aws_security_group.ecs_tasks_sg.id]
    subnets          = module.vpc.private_subnets
    assign_public_ip = false
  }
  deployment_circuit_breaker {
    enable   = false
    rollback = false
  }
  platform_version = "1.4.0"
  propagate_tags   = "SERVICE"

  task_definition = aws_ecs_task_definition.td.arn
  tags = {
    Name = "${local.name_prefix}-ecs-tasks-sg"
    Type = "Civiform Fargate Service"
  }
}

#------------------------------------------------------------------------------
# AWS SECURITY GROUP - ECS Tasks, allow traffic only from Load Balancer
#------------------------------------------------------------------------------
resource "aws_security_group" "ecs_tasks_sg" {
  name        = "${local.name_prefix}-ecs-tasks-sg"
  description = "Allow inbound access from the LB only"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name = "${local.name_prefix}-ecs-tasks-sg"
    Type = "Civiform Fargate Service"
  }
}

resource "aws_security_group_rule" "egress" {
  security_group_id = aws_security_group.ecs_tasks_sg.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "ingress_through_http_and_https" {
  for_each                 = toset(concat(local.lb_https_tgs_ports, local.lb_http_tgs_ports))
  security_group_id        = aws_security_group.ecs_tasks_sg.id
  type                     = "ingress"
  from_port                = each.key
  to_port                  = each.key
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lb_access_sg.id
}

module "ecs-autoscaling" {
  source  = "cn-terraform/ecs-service-autoscaling/aws"
  version = "1.0.6"

  name_prefix               = local.name_prefix
  ecs_cluster_name          = module.ecs_cluster.aws_ecs_cluster_cluster_name
  ecs_service_name          = aws_ecs_service.service.name
  max_cpu_threshold         = var.ecs_max_cpu_threshold
  min_cpu_threshold         = var.ecs_min_cpu_threshold
  max_cpu_evaluation_period = "3"
  min_cpu_evaluation_period = "3"
  max_cpu_period            = "60"
  min_cpu_period            = "60"
  scale_target_max_capacity = 5
  scale_target_min_capacity = 1
  tags = {
    Name = "${var.app_prefix} Civiform Fargate Service"
    Type = "Civiform Fargate Service"
  }
}
## end ecs-fargate-service replacement

locals {
  lb_https_listeners_arns = [for listener in aws_lb_listener.lb_https_listeners : listener.arn]
}
resource "aws_lb_listener_rule" "block_external_traffic_to_metrics_rule" {
  count        = length(local.lb_https_listeners_arns)
  listener_arn = local.lb_https_listeners_arns[count.index]

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
