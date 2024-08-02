# This is a collection of resources that we used to rely on
# cn-terraform/ecs-fargate-service/aws to provide, but this module
# frequently broke us, so we include the necessary resources here instead.
# The resources have been streamlined for our purposes.
#
# In places where we were not defining variables, the defaults from
# https://github.com/cn-terraform/terraform-aws-ecs-fargate-service/blob/a1c2ea9fddb0ce682d6dac2e9af6b615a994e494/variables.tf
# were used.

### ecs-alb replacement
#------------------------------------------------------------------------------
# S3 BUCKET - For access logs
#------------------------------------------------------------------------------
data "aws_elb_service_account" "default" {}

locals {
  # While we don't really need to do this, it keeps resource names consistent
  # with previous deploys to avoid destroying and recreating a bunch of
  # resources.
  name_prefix = "${var.app_prefix}-civiform"
}

#------------------------------------------------------------------------------
# APPLICATION LOAD BALANCER
#------------------------------------------------------------------------------
resource "aws_lb" "civiform_lb" {
  name = substr("${local.name_prefix}-lb", 0, 31)

  internal                         = false
  load_balancer_type               = "application"
  drop_invalid_header_fields       = false
  subnets                          = var.public_subnets
  idle_timeout                     = 60
  enable_deletion_protection       = false
  enable_cross_zone_load_balancing = false
  enable_http2                     = true
  ip_address_type                  = "ipv4"
  security_groups                  = [aws_security_group.lb_access_sg.id]

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-lb"
    },
  )
}

moved {
  from = module.ecs-alb[0].aws_lb.lb
  to   = aws_lb.civiform_lb
}

#------------------------------------------------------------------------------
# ACCESS CONTROL TO APPLICATION LOAD BALANCER
#------------------------------------------------------------------------------
resource "aws_security_group" "lb_access_sg" {
  name        = "${local.name_prefix}-lb-access-sg"
  description = "Controls access to the Load Balancer"
  vpc_id      = var.vpc_id

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-lb-access-sg"
    },
  )
}

moved {
  from = module.ecs-alb[0].aws_security_group.lb_access_sg
  to   = aws_security_group.lb_access_sg
}

resource "aws_security_group_rule" "ingress_through_http" {
  security_group_id = aws_security_group.lb_access_sg.id
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  prefix_list_ids   = []
}

moved {
  from = module.ecs-alb[0].aws_security_group_rule.ingress_through_http["default_http"]
  to   = aws_security_group_rule.ingress_through_http
}

resource "aws_security_group_rule" "ingress_through_https" {
  security_group_id = aws_security_group.lb_access_sg.id
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  prefix_list_ids   = []
}

moved {
  from = module.ecs-alb[0].aws_security_group_rule.ingress_through_https["default_http"]
  to   = aws_security_group_rule.ingress_through_https
}

#------------------------------------------------------------------------------
# AWS LOAD BALANCER - Target Groups
#------------------------------------------------------------------------------
resource "aws_lb_target_group" "lb_https_tgs" {
  name                          = "${var.app_prefix}-https-${var.https_target_port}"
  port                          = var.https_target_port
  protocol                      = "HTTP"
  vpc_id                        = var.vpc_id
  deregistration_delay          = 300
  slow_start                    = 0
  load_balancing_algorithm_type = "round_robin"
  target_type                   = "ip"

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = true
  }

  health_check {
    enabled             = true
    interval            = 10
    path                = "/playIndex"
    protocol            = "HTTP"
    timeout             = 30
    healthy_threshold   = 2
    unhealthy_threshold = 10
    matcher             = "200"
  }

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-https-${var.https_target_port}"
    },
  )

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_lb.civiform_lb]
}

moved {
  from = module.ecs-alb[0].aws_lb_target_group.lb_https_tgs["default_http"]
  to   = aws_lb_target_group.lb_https_tgs
}

#------------------------------------------------------------------------------
# AWS LOAD BALANCER - Listeners
#------------------------------------------------------------------------------
resource "aws_lb_listener" "lb_http_listeners" {
  load_balancer_arn = aws_lb.civiform_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      host        = "#{host}"
      path        = "/#{path}"
      port        = 443
      protocol    = "HTTPS"
      query       = "#{query}"
      status_code = "HTTP_301"
    }
  }

  tags = var.tags
}

moved {
  from = module.ecs-alb[0].aws_lb_listener.lb_http_listeners["default_http"]
  to   = aws_lb_listener.lb_http_listeners
}

resource "aws_lb_listener" "lb_https_listeners" {
  load_balancer_arn = aws_lb.civiform_lb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.default_certificate_arn

  default_action {
    target_group_arn = aws_lb_target_group.lb_https_tgs.arn
    type             = "forward"
  }

  tags = var.tags
}

moved {
  from = module.ecs-alb[0].aws_lb_listener.lb_https_listeners["default_http"]
  to   = aws_lb_listener.lb_https_listeners
}
### end ecs-alb replacement

#------------------------------------------------------------------------------
# AWS ECS SERVICE
#------------------------------------------------------------------------------
resource "aws_ecs_service" "service" {
  name = "${local.name_prefix}-service"
  # capacity_provider_strategy - (Optional) The capacity provider strategy to use for the service. Can be one or more. Defined below.
  cluster                            = var.ecs_cluster_arn
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  desired_count                      = var.desired_count
  enable_ecs_managed_tags            = false
  enable_execute_command             = false
  health_check_grace_period_seconds  = 20
  launch_type                        = "FARGATE"
  force_new_deployment               = false
  platform_version                   = "1.4.0"
  propagate_tags                     = "SERVICE"
  task_definition                    = var.task_definition_arn

  load_balancer {
    target_group_arn = aws_lb_target_group.lb_https_tgs.arn
    container_name   = local.name_prefix
    container_port   = tostring(aws_lb_target_group.lb_https_tgs.port)
  }
  network_configuration {
    security_groups  = [aws_security_group.ecs_tasks_sg.id]
    subnets          = var.private_subnets
    assign_public_ip = false
  }

  # The circuit breaker will mark the deployment as failed when the service does
  # not come up or is not marked as healthy after 10 tries. This prevents the
  # deployment from pulling the civiform image over and over, which can cause
  # DockerHub rate limiting. The 10 tries is the minimum value given that
  # desired_count < 20 (desired_count is probably 1 for our use case).
  # https://docs.aws.amazon.com/AmazonECS/latest/userguide/deployment-circuit-breaker.html
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-ecs-tasks-sg"
    },
  )
}

#------------------------------------------------------------------------------
# AWS SECURITY GROUP - ECS Tasks, allow traffic only from Load Balancer
#------------------------------------------------------------------------------
resource "aws_security_group" "ecs_tasks_sg" {
  name        = "${local.name_prefix}-ecs-tasks-sg"
  description = "Allow inbound access from the LB only"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-ecs-tasks-sg"
    },
  )
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
  security_group_id        = aws_security_group.ecs_tasks_sg.id
  type                     = "ingress"
  from_port                = tostring(aws_lb_target_group.lb_https_tgs.port)
  to_port                  = tostring(aws_lb_target_group.lb_https_tgs.port)
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lb_access_sg.id
}

moved {
  from = aws_security_group_rule.ingress_through_http_and_https["9000"]
  to   = aws_security_group_rule.ingress_through_http_and_https
}

module "ecs-autoscaling" {
  source  = "cn-terraform/ecs-service-autoscaling/aws"
  version = "1.0.6"

  name_prefix               = local.name_prefix
  ecs_cluster_name          = var.ecs_cluster_name
  ecs_service_name          = aws_ecs_service.service.name
  max_cpu_threshold         = var.max_cpu_threshold
  min_cpu_threshold         = var.min_cpu_threshold
  max_cpu_evaluation_period = var.max_cpu_evaluation_period
  min_cpu_evaluation_period = var.min_cpu_evaluation_period
  max_cpu_period            = var.max_cpu_period
  min_cpu_period            = var.min_cpu_period
  scale_target_max_capacity = var.scale_target_max_capacity
  scale_target_min_capacity = var.scale_target_min_capacity
  tags                      = var.tags
}

moved {
  from = module.ecs-autoscaling[0]
  to   = module.ecs-autoscaling
}
