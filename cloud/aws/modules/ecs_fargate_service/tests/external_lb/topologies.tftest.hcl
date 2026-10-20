# Plan-only suite for ecs_fargate_service.
#
# Every run block plans the module itself (module source "../../") against a
# mocked aws provider: no credentials, no backend, no state. Planning the module
# directly, rather than through the fixture root's module call, is what lets
# assertions and expect_failures address its resources; from a root, only a
# child module's outputs are visible.
#
# Computed attributes (IDs, ARNs) are unknown during plan, so assertions stick
# to counts, booleans, nulls, and values the run block passed in. Where a run
# block has to compare a computed value, an override_resource gives that one
# attribute a placeholder that is known at plan time.

mock_provider "aws" {}

# Inputs shared by every run block. Individual run blocks override only what
# they toggle.
variables {
  app_prefix          = "fixture"
  vpc_id              = "vpc-00000000000000000"
  public_subnets      = ["subnet-00000000000000001", "subnet-00000000000000002"]
  private_subnets     = ["subnet-00000000000000000"]
  ecs_cluster_arn     = "arn:aws:ecs:us-east-1:000000000000:cluster/fixture"
  ecs_cluster_name    = "fixture"
  task_definition_arn = "arn:aws:ecs:us-east-1:000000000000:task-definition/fixture:1"
  container_name      = "fixture-civiform"
}

# ---------------------------------------------------------------------------
# Externally managed load balancer
# ---------------------------------------------------------------------------

run "external_lb_creates_no_alb" {
  command = plan

  module {
    source = "../../"
  }

  variables {
    create_load_balancer          = false
    existing_lb_security_group_id = "sg-00000000000000000"
  }

  assert {
    condition     = length(aws_lb.civiform_lb) == 0
    error_message = "external topology must not create an ALB"
  }

  assert {
    condition     = length(aws_lb_listener.lb_https_listeners) == 0
    error_message = "external topology must not create an HTTPS listener"
  }

  assert {
    condition     = length(aws_lb_listener.lb_http_listeners) == 0
    error_message = "external topology must not create an HTTP listener"
  }

  assert {
    condition     = length(aws_security_group.lb_access_sg) == 0
    error_message = "external topology must not create an LB security group"
  }

  assert {
    condition     = length(aws_security_group_rule.ingress_through_http) == 0 && length(aws_security_group_rule.ingress_through_https) == 0
    error_message = "external topology must not create LB ingress rules"
  }

  assert {
    condition     = length(aws_s3_bucket.lb_logs) == 0
    error_message = "external topology must not create an access-log bucket"
  }

  assert {
    condition     = output.https_listener_arn == null && output.aws_lb_civiform_lb_arn == null && output.aws_security_group_lb_access_sg_id == null
    error_message = "the three LB outputs must be null in the external topology"
  }

  assert {
    condition     = aws_security_group_rule.ingress_through_http_and_https.source_security_group_id == "sg-00000000000000000"
    error_message = "ECS task ingress must be sourced from the caller's LB security group"
  }
}

run "external_lb_without_security_group_fails_precondition" {
  command = plan

  module {
    source = "../../"
  }

  variables {
    create_load_balancer          = false
    existing_lb_security_group_id = null
  }

  # The target group carries two preconditions. "fixture" is well under the
  # length cap, so only the security-group one can trip here.
  expect_failures = [
    aws_lb_target_group.lb_https_tgs,
  ]
}

# ---------------------------------------------------------------------------
# Dedicated load balancer (default topology)
# ---------------------------------------------------------------------------

run "default_lb_creates_alb_listeners_and_sg" {
  command = plan

  module {
    source = "../../"
  }

  variables {
    create_load_balancer = true
  }

  # Pins the module-managed security group's ID so the ingress rule assertion
  # below can compare against it during plan.
  override_resource {
    target          = aws_security_group.lb_access_sg
    override_during = plan
    values = {
      id = "sg-module-managed-lb"
    }
  }

  assert {
    condition     = length(aws_lb.civiform_lb) == 1
    error_message = "default topology must create exactly one ALB"
  }

  assert {
    condition     = length(aws_lb_listener.lb_https_listeners) == 1
    error_message = "default topology must create exactly one HTTPS listener"
  }

  assert {
    condition     = length(aws_lb_listener.lb_http_listeners) == 1
    error_message = "default topology must create exactly one HTTP listener"
  }

  assert {
    condition     = length(aws_security_group.lb_access_sg) == 1
    error_message = "default topology must create exactly one LB security group"
  }

  assert {
    condition     = aws_security_group_rule.ingress_through_http_and_https.source_security_group_id == "sg-module-managed-lb"
    error_message = "ECS task ingress must be sourced from the module-managed LB security group, not existing_lb_security_group_id"
  }
}

run "default_lb_without_logging_creates_no_bucket" {
  command = plan

  module {
    source = "../../"
  }

  variables {
    create_load_balancer = true
    lb_logging_enabled   = false
  }

  assert {
    condition     = length(aws_s3_bucket.lb_logs) == 0 && length(aws_s3_bucket_policy.lb_logs_policy) == 0
    error_message = "no access-log bucket or policy when logging is off"
  }

  assert {
    condition     = aws_lb.civiform_lb[0].access_logs[0].enabled == false
    error_message = "ALB access logging must be off when lb_logging_enabled is false"
  }
}

run "default_lb_with_logging_creates_bucket" {
  command = plan

  module {
    source = "../../"
  }

  variables {
    create_load_balancer = true
    lb_logging_enabled   = true
  }

  assert {
    condition     = length(aws_s3_bucket.lb_logs) == 1 && length(aws_s3_bucket_policy.lb_logs_policy) == 1
    error_message = "access-log bucket and policy must exist when logging is on and the LB is created"
  }

  assert {
    condition     = aws_s3_bucket.lb_logs[0].bucket == "fixture-civiform-lb-logs"
    error_message = "access-log bucket name must derive from app_prefix"
  }

  assert {
    condition     = aws_lb.civiform_lb[0].access_logs[0].enabled == true
    error_message = "ALB access logging must be on when lb_logging_enabled is true"
  }
}

run "external_lb_with_logging_creates_no_bucket" {
  command = plan

  module {
    source = "../../"
  }

  variables {
    create_load_balancer          = false
    existing_lb_security_group_id = "sg-00000000000000000"
    lb_logging_enabled            = true
  }

  assert {
    condition     = length(aws_s3_bucket.lb_logs) == 0
    error_message = "logging must not create a bucket when there is no module-managed LB to log"
  }
}

run "default_lb_without_http_listener" {
  command = plan

  module {
    source = "../../"
  }

  variables {
    create_load_balancer = true
    enable_http_listener = false
  }

  assert {
    condition     = length(aws_lb_listener.lb_http_listeners) == 0
    error_message = "no HTTP listener when enable_http_listener is false"
  }

  assert {
    condition     = length(aws_security_group_rule.ingress_through_http) == 0
    error_message = "no HTTP ingress rule when enable_http_listener is false"
  }

  assert {
    condition     = length(aws_lb_listener.lb_https_listeners) == 1 && length(aws_security_group_rule.ingress_through_https) == 1
    error_message = "HTTPS listener and ingress rule must be unaffected by enable_http_listener"
  }
}

# ---------------------------------------------------------------------------
# Naming
# ---------------------------------------------------------------------------

run "app_prefix_at_length_cap_passes" {
  command = plan

  module {
    source = "../../"
  }

  variables {
    # 21 characters: "<prefix>-https-9000" is exactly 32.
    app_prefix = "abcdefghijklmnopqrstu"

    # TODO(plans/list.md item 58): at exactly 21 characters the ALB name
    # substr() leaves a trailing hyphen, which the provider rejects, so the
    # default topology cannot plan at the cap. Planning the external topology
    # keeps this a test of the precondition alone. Once the name is fixed,
    # replace the two lines below with the commented-out one.
    # create_load_balancer = true
    create_load_balancer          = false
    existing_lb_security_group_id = "sg-00000000000000000"
  }

  assert {
    condition     = length(aws_lb_target_group.lb_https_tgs.name) == 32
    error_message = "target group name should sit exactly at the 32-character cap"
  }
}

run "app_prefix_over_length_cap_fails_precondition" {
  command = plan

  module {
    source = "../../"
  }

  variables {
    # Creating the LB keeps the security-group precondition satisfied, so only
    # the length precondition can trip here.
    create_load_balancer = true
    # 22 characters: "<prefix>-https-9000" is 33.
    app_prefix = "abcdefghijklmnopqrstuv"
  }

  expect_failures = [
    aws_lb_target_group.lb_https_tgs,
  ]
}
