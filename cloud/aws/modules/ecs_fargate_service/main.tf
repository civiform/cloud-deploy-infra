# This is a collection of resources that we used to rely on
# cn-terraform/ecs-fargate-service/aws to provide, but this module
# frequently broke us, so we include the necessary resources here instead.
#
# In places where we were not defining variables, the defaults from
# https://github.com/cn-terraform/terraform-aws-ecs-fargate-service/blob/a1c2ea9fddb0ce682d6dac2e9af6b615a994e494/variables.tf
# were used.

### ecs-alb replacement
#------------------------------------------------------------------------------
# S3 BUCKET - For access logs
#------------------------------------------------------------------------------
data "aws_elb_service_account" "default" {}

#------------------------------------------------------------------------------
# APPLICATION LOAD BALANCER
#------------------------------------------------------------------------------
resource "aws_lb" "lb" {
  name = substr("${var.name_prefix}-lb", 0, 31)

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

  tags = {
    Name = "${var.name_prefix}-lb"
    Type = "Civiform Fargate Service"
  }
}

#------------------------------------------------------------------------------
# ACCESS CONTROL TO APPLICATION LOAD BALANCER
#------------------------------------------------------------------------------
resource "aws_security_group" "lb_access_sg" {
  name        = "${var.name_prefix}-lb-access-sg"
  description = "Controls access to the Load Balancer"
  vpc_id      = var.vpc_id
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.name_prefix}-lb-access-sg"
    Type = "Civiform Fargate Service"
  }
}

resource "aws_security_group_rule" "ingress_through_http" {
  for_each          = var.lb_http_ports
  security_group_id = aws_security_group.lb_access_sg.id
  type              = "ingress"
  from_port         = each.value.listener_port
  to_port           = each.value.listener_port
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  prefix_list_ids   = []
}

resource "aws_security_group_rule" "ingress_through_https" {
  for_each          = var.lb_https_ports
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
    for name, config in var.lb_http_ports : name => config
    if lookup(config, "type", "") == "" || lookup(config, "type", "") == "forward"
  }
  name                          = "${var.name_prefix}-http-${each.value.target_group_port}"
  port                          = each.value.target_group_port
  protocol                      = lookup(each.value, "target_group_protocol", "HTTP")
  vpc_id                        = var.vpc_id
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
    Name = "${var.name_prefix}-http-${each.value.target_group_port}"
    Type = "Civiform Fargate Service"
  }
  lifecycle {
    create_before_destroy = true
  }
  depends_on = [aws_lb.lb]
}

resource "aws_lb_target_group" "lb_https_tgs" {
  for_each = {
    for name, config in var.lb_https_ports : name => config
    if lookup(config, "type", "") == "" || lookup(config, "type", "") == "forward"
  }
  name                          = "${var.name_prefix}-https-${each.value.target_group_port}"
  port                          = each.value.target_group_port
  protocol                      = lookup(each.value, "target_group_protocol", "HTTPS")
  vpc_id                        = var.vpc_id
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
    Name = "${var.name_prefix}-https-${each.value.target_group_port}"
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
  for_each          = var.lb_http_ports
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
    Name = "${var.name_prefix} Civiform Fargate Service"
    Type = "Civiform Fargate Service"
  }
}

resource "aws_lb_listener" "lb_https_listeners" {
  for_each          = var.lb_https_ports
  load_balancer_arn = aws_lb.lb.arn
  port              = each.value.listener_port
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.default_certificate_arn

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
    Name = "${var.name_prefix} Civiform Fargate Service"
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
  name = "${var.name_prefix}-service"
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

  dynamic "load_balancer" {
    for_each = local.lb_http_tgs_map_arn_port
    content {
      target_group_arn = load_balancer.key
      container_name   = var.name_prefix
      container_port   = load_balancer.value
    }
  }
  dynamic "load_balancer" {
    for_each = local.lb_https_tgs_map_arn_port
    content {
      target_group_arn = load_balancer.key
      container_name   = var.name_prefix
      container_port   = load_balancer.value
    }
  }
  network_configuration {

    security_groups  = [aws_security_group.ecs_tasks_sg.id]
    subnets          = var.private_subnets
    assign_public_ip = false
  }
  deployment_circuit_breaker {
    enable   = false
    rollback = false
  }
  platform_version = "1.4.0"
  propagate_tags   = "SERVICE"

  task_definition = var.task_definition_arn
  tags = {
    Name = "${var.name_prefix}-ecs-tasks-sg"
    Type = "Civiform Fargate Service"
  }
}

#------------------------------------------------------------------------------
# AWS SECURITY GROUP - ECS Tasks, allow traffic only from Load Balancer
#------------------------------------------------------------------------------
resource "aws_security_group" "ecs_tasks_sg" {
  name        = "${var.name_prefix}-ecs-tasks-sg"
  description = "Allow inbound access from the LB only"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name_prefix}-ecs-tasks-sg"
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

  name_prefix               = var.name_prefix
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
  tags = {
    Name = "${var.name_prefix} Civiform Fargate Service"
    Type = "Civiform Fargate Service"
  }
}