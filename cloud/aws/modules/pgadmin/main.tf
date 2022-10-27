# Allow load balancer to accept traffic on new port.
resource "aws_security_group_rule" "pgadmin_lb" {
  description       = "Allow tcp traffic on port 4433"
  security_group_id = var.lb_access_sg_id
  cidr_blocks       = ["0.0.0.0/0"] # Allow traffic from all IPs.
  type              = "ingress"
  from_port         = 4433
  to_port           = 4433
  protocol          = "tcp"
}

# Add new listener to existing load balancer for the main civiform server.
#
# We do this to reuse the exiting TLS infra so that we do not need to manage a separate certificate.
resource "aws_lb_listener" "pgadmin" {
  load_balancer_arn = var.lb_arn
  port              = 4433
  protocol          = "HTTPS"
  certificate_arn   = var.lb_ssl_cert_arn
  ssl_policy        = "ELBSecurityPolicy-2016-08" # Default policy.
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.pgadmin.arn
  }
}

# Traffic from load balancer is forwarded to IPs in this target group.
resource "aws_lb_target_group" "pgadmin" {
  name        = "${var.app_prefix}-pgadmin"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  # Specific config for pgadmin container.
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 20
    timeout             = 10
    path                = "/misc/ping"
  }
}

# Security group for pgadmin tasks to run in.
resource "aws_security_group" "pgadmin_tasks" {
  name        = "${var.app_prefix}-pgadmin-tasks"
  description = "Allow HTTP traffic on port 80."
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTP from load balancer"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [var.lb_access_sg_id]
  }

  egress {
    description = "HTTPS egress"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description     = "postgres egress"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.db_sg_id]
  }
}

# Run a pgadmin container via a ecs service.
resource "aws_ecs_service" "pgadmin" {
  name            = "${var.app_prefix}-pgadmin"
  cluster         = var.ecs_cluster_arn
  task_definition = aws_ecs_task_definition.pgadmin.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets = var.subnet_ids
    security_groups = [
      aws_security_group.pgadmin_tasks.id
    ]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.pgadmin.arn
    container_name   = "${var.app_prefix}-pgadmin"
    container_port   = 80
  }
}

# IAM config for pgadmin tasks.
locals {
  name_prefix = "${var.app_prefix}-civiform"
  tags = {
    Name = "${var.app_prefix} Civiform EC2 Task Definition"
    Type = "Civiform EC2 Task Definition"
  }
  civiform_pgadmin_task_execution_role_custom_policies = [
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
              aws_secretsmanager_secret.pgadmin_username_secret.arn,
              aws_secretsmanager_secret.pgadmin_password_secret.arn,
              var.db_username_secret_arn,
            ]
          },
          {
            "Effect" : "Allow",
            "Action" : [
              "kms:Decrypt",
            ],
            "Resource" : [var.secrets_kms_key_arn]
          },
        ]
      }
    )
  ]
}
resource "aws_iam_role" "civiform_pgadmin_task_execution_role" {
  name               = "${local.name_prefix}-pgadmin-task-execution-role"
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
resource "aws_iam_role_policy_attachment" "civiform_pgadmin_task_execution_role_policy_attach" {
  role       = aws_iam_role.civiform_pgadmin_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
resource "aws_iam_policy" "civiform_pgadmin_task_execution_role_custom_policy" {
  count       = length(local.civiform_pgadmin_task_execution_role_custom_policies)
  name        = "${local.name_prefix}-pgadmin-task-execution-role-custom-policy-${count.index}"
  description = "A custom policy for ${local.name_prefix}-pgadmin-task-execution-role IAM Role"
  policy      = local.civiform_pgadmin_task_execution_role_custom_policies[count.index]
  tags        = local.tags
}
resource "aws_iam_role_policy_attachment" "civiform_pgadmin_task_execution_role_custom_policy" {
  count      = length(local.civiform_pgadmin_task_execution_role_custom_policies)
  role       = aws_iam_role.civiform_pgadmin_task_execution_role.name
  policy_arn = aws_iam_policy.civiform_pgadmin_task_execution_role_custom_policy[count.index].arn
}
