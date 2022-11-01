resource "aws_ecs_task_definition" "pgadmin" {
  family = "${local.name_prefix}-pgadmin"

  cpu    = 1024
  memory = 2048

  container_definitions = jsonencode([
    module.pgadmin_init_container_def.json_map_object,
    module.pgadmin_container_def.json_map_object
  ])

  execution_role_arn       = aws_iam_role.civiform_pgadmin_task_execution_role.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  volume {
    name = "config"
  }

  tags = local.tags
}

module "pgadmin_container_def" {
  source  = "cloudposse/ecs-container-definition/aws"
  version = "0.58.1"

  container_name  = "${local.name_prefix}"
  container_image = "dpage/pgadmin4:6.15"
  container_depends_on = [
    { containerName = "${local.name_prefix}-init", condition = "COMPLETE" }
  ]

  secrets = [
    {
      name      = "PGADMIN_DEFAULT_EMAIL"
      valueFrom = aws_secretsmanager_secret_version.pgadmin_username_secret_version.arn
    },
    {
      name      = "PGADMIN_DEFAULT_PASSWORD"
      valueFrom = aws_secretsmanager_secret_version.pgadmin_password_secret_version.arn
    }
  ]

  map_environment = {
    PGADMIN_SERVER_JSON_FILE = "/config/servers.json"
  }

  port_mappings = [
    {
      containerPort = 80
      hostPort      = 80
      protocol      = "tcp"
    },
  ]

  mount_points = [
    {
      containerPath = "/config",
      sourceVolume  = "config",
      readOnly      = false
    }
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
  version   = "1.0.12"
  logs_path = "${local.name_prefix}-logs/"
  tags = {
    Name = "${var.app_prefix} CiviForm pgAdmin Cloud Watch Logs"
    Type = "CiviForm pgAdmin Cloud Watch Logs"
  }
}

# Pgadmin supports server import via a json file readable by the pgadmin process. This init
# container writes such a file to a volume readable by the pgadmin container.
#
# The pgadmin container runs as a user that does not have permissions to write to most
# of the container filesystem which is why we use a separate bash image to write the file.
module "pgadmin_init_container_def" {
  source  = "cloudposse/ecs-container-definition/aws"
  version = "0.58.1"

  container_name  = "${local.name_prefix}-init"
  container_image = "bash:4.4"
  essential       = false # Makes it so other containers in the same task are not stopped when this container exits.

  entrypoint = [
    "sh", "-c"
  ]
  command = [
    "printf '{ \"Servers\": { \"1\": { \"Group\": \"CiviForm\", \"Name\": \"civiform-db\", \"Host\": \"%s\", \"Port\": %d, \"Username\": \"%s\", \"SSLMode\": \"prefer\", \"MaintenanceDB\": \"postgres\" } } }\n' \"$DB_ADDRESS\" \"$DB_PORT\" \"$DB_USERNAME\" > /config/servers.json && cat /config/servers.json"
  ]

  secrets = [
    {
      name      = "DB_USERNAME"
      valueFrom = var.db_username_secret_arn,
    }
  ]

  map_environment = {
    DB_ADDRESS = var.db_address
    DB_PORT    = var.db_port
  }

  mount_points = [
    {
      containerPath = "/config",
      sourceVolume  = "config",
      readOnly      = false
    }
  ]

  log_configuration = {
    logDriver = "awslogs"
    options = {
      "awslogs-region"        = var.aws_region
      "awslogs-stream-prefix" = "ecs"
      "awslogs-group"         = module.pgadmin_init_logs.logs_path
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
module "pgadmin_init_logs" {
  source    = "cn-terraform/cloudwatch-logs/aws"
  version   = "1.0.12"
  logs_path = "${local.name_prefix}-init-logs/"
  tags = {
    Name = "${var.app_prefix} CiviForm pgAdmin init Cloud Watch Logs"
    Type = "CiviForm pgAdmin init Cloud Watch Logs"
  }
}
