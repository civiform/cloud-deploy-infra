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
  container_memory             = var.ecs_server_container_memory
  container_memory_reservation = var.ecs_server_container_memory_reservation

  # The "name" key should match the environment variable used within the Civiform application
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
    },
    {
      name      = "ESRI_ARCGIS_API_TOKEN"
      valueFrom = aws_secretsmanager_secret_version.esri_arcgis_api_token_secret_version.arn
    }
  ]

  map_environment = merge({
    PORT                      = var.port
    DB_JDBC_STRING            = "jdbc:postgresql://${aws_db_instance.civiform.address}:${aws_db_instance.civiform.port}/postgres?ssl=true&sslmode=require"
    STORAGE_SERVICE_NAME      = "s3"
    AWS_S3_BUCKET_NAME        = aws_s3_bucket.civiform_files_s3.id
    AWS_S3_PUBLIC_BUCKET_NAME = aws_s3_bucket.civiform_public_files_s3.id
    CLIENT_IP_TYPE            = "FORWARDED" // must be "FORWARDED" for all AWS deployments
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
    timeout     = 30
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
  container_memory             = var.ecs_metrics_scraper_container_memory
  container_memory_reservation = var.ecs_metrics_scraper_container_memory_reservation

  map_environment = merge({
    PROMETHEUS_WRITE_ENDPOINT = var.monitoring_stack_enabled ? "${aws_prometheus_workspace.metrics[0].prometheus_endpoint}api/v1/remote_write" : ""
    AWS_REGION                = var.aws_region
  }, var.civiform_server_environment_variables)

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
              aws_secretsmanager_secret.esri_arcgis_api_token_secret.arn,
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

data "aws_lb" "alb_data" {
  arn       = module.ecs_fargate_service.alb_arn  # Access the ALB's ARN from the module output
  depends_on = [module.ecs_fargate_service]       # Wait for the module to create the ALB
}

# Get the IDs of the EC2 instances backing the ALB
data "aws_instances" "alb_instances" {
  filter {
    name = "load-balancer-arn"
    values = [data.aws_lb.alb_data.arn]
  }
}

# Attach ALB instances to the target group (one attachment per instance)
resource "aws_lb_target_group_attachment" "nlb_tg_attachment" {
  # Assuming the ALB is in a private subnet and can only be accessed by the NLB, the NLB's target group should be defined as follows:
  count         = length(data.aws_instances.alb_instances.ids)

  target_group_arn = module.ecs_fargate_service.lb_target_group_arn 
  target_id        = data.aws_instances.alb_instances.ids[count.index]
  port            = var.https_target_port

  depends_on = [module.ecs_fargate_service] 
}

module "ecs_fargate_service" {
  source                    = "../../modules/ecs_fargate_service"
  app_prefix                = var.app_prefix
  desired_count             = var.fargate_desired_task_count
  default_certificate_arn   = var.ssl_certificate_arn
  ssl_policy                = "ELBSecurityPolicy-FS-1-2-Res-2020-10"
  vpc_id                    = local.vpc_id
  task_definition_arn       = var.monitoring_stack_enabled ? aws_ecs_task_definition.civiform_with_monitoring.arn : aws_ecs_task_definition.civiform_only.arn
  container_name            = "${var.app_prefix}-civiform"
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

  tags = {
    Name = "${var.app_prefix} Civiform Fargate Service"
    Type = "Civiform Fargate Service"
  }
}
