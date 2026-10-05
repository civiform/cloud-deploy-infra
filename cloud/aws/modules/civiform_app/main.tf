# The CiviForm compute layer: the server and metrics scraper container
# definitions, the two task definitions, and the ECS task execution role (in
# iam.tf). These resources were extracted verbatim from
# cloud/aws/templates/aws_oidc/app.tf; `moved` blocks in that root preserve
# their state addresses and must not be removed.
#
# The module deliberately creates neither the log groups nor the secrets nor
# the buckets it references. Those have lifecycles of their own and are passed
# in by the caller.

locals {
  # While we don't really need to do this, it keeps resource names consistent
  # with previous deploys to avoid destroying and recreating a bunch of
  # resources.
  name_prefix = "${var.app_prefix}-civiform"

  tags = merge({
    Name = "${var.app_prefix} Civiform EC2 Task Definition"
    Type = "Civiform EC2 Task Definition"
  }, var.tags)

  server_container_name = "${var.app_prefix}-civiform"
}

module "civiform_server_container_def" {
  source  = "cloudposse/ecs-container-definition/aws"
  version = "0.61.2"

  container_name               = local.server_container_name
  container_image              = "${var.civiform_image_repo}:${var.image_tag}"
  container_memory             = var.ecs_server_container_memory
  container_memory_reservation = var.ecs_server_container_memory_reservation

  # The "name" key should match the environment variable used within the Civiform application
  secrets = [
    for secret in var.secrets : {
      name      = secret.name
      valueFrom = secret.value_arn
    }
  ]

  map_environment = merge({
    PORT                      = var.port
    DB_JDBC_STRING            = var.db_jdbc_string
    STORAGE_SERVICE_NAME      = "s3"
    AWS_S3_BUCKET_NAME        = var.file_storage_bucket_name
    AWS_S3_PUBLIC_BUCKET_NAME = var.public_file_storage_bucket_name
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
      "awslogs-group"         = var.log_group_name
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
  version = "0.61.2"

  container_name               = "${var.app_prefix}-metrics-scraper"
  container_image              = var.scraper_image
  container_memory             = var.ecs_metrics_scraper_container_memory
  container_memory_reservation = var.ecs_metrics_scraper_container_memory_reservation

  map_environment = merge({
    PROMETHEUS_WRITE_ENDPOINT = var.prometheus_remote_write_endpoint
    AWS_REGION                = var.aws_region
  }, var.civiform_server_environment_variables)

  log_configuration = {
    logDriver = "awslogs"
    options = {
      "awslogs-region"        = var.aws_region
      "awslogs-stream-prefix" = "ecs"
      "awslogs-group"         = var.scraper_log_group_name
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
