resource "aws_ecs_task_definition" "pgadmin" {
  family = local.name_prefix

  cpu    = 1024
  memory = 2048

  container_definitions = jsonencode([
    module.pgadmin_container_def.json_map_object
  ])

  execution_role_arn       = aws_iam_role.civiform_pgadmin_task_execution_role.arn
  task_role_arn            = aws_iam_role.civiform_pgadmin_task_role.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  tags = local.tags
}

module "pgadmin_container_def" {
  source  = "cloudposse/ecs-container-definition/aws"
  version = "0.61.2"

  container_name  = local.name_prefix
  container_image = var.pgadmin_image

  secrets = [
    {
      name      = "PGADMIN_DEFAULT_EMAIL"
      valueFrom = aws_secretsmanager_secret_version.pgadmin_username_secret_version.arn
    },
    {
      name      = "PGADMIN_DEFAULT_PASSWORD"
      valueFrom = aws_secretsmanager_secret_version.pgadmin_password_secret_version.arn
    },
    {
      name      = "DB_USERNAME"
      valueFrom = var.db_username_secret_arn,
    }
  ]

  map_environment = {
    DB_ADDRESS = var.db_address
    DB_PORT    = var.db_port
  }

  port_mappings = [
    {
      containerPort = 80
      hostPort      = 80
      protocol      = "tcp"
    },
  ]

  log_configuration = {
    logDriver = "awslogs"
    options = {
      "awslogs-region"        = var.aws_region
      "awslogs-stream-prefix" = "ecs"
      "awslogs-group"         = module.pgadmin_logs.logs_path
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
module "pgadmin_logs" {
  source    = "cn-terraform/cloudwatch-logs/aws"
  version   = "1.0.13"
  logs_path = "${local.name_prefix}-logs/"
  tags = {
    Name = "${var.app_prefix} CiviForm pgAdmin Cloud Watch Logs"
    Type = "CiviForm pgAdmin Cloud Watch Logs"
  }
}
