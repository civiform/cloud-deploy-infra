# Plan-only suite for the aws_oidc root.
#
# One file for the whole root so the fixture below (mocks, overrides, and the
# variables block) lives in one place; terraform test has no way to share it
# between files. Sections are marked with banner comments.
#
# Backend: this root declares `backend "s3" {}` with no settings. The suite
# runs against the root itself, not through a wrapper module. `terraform test`
# keeps state in memory, and the `terraform init -backend=false` that
# bin/validate already does is enough for it. No credentials, no backend, no
# state.
#
# Every run block plans with a mocked aws provider. Computed attributes are
# unknown during plan, so assertions stick to counts, booleans, and values the
# run block passed in. The `random` provider is real; it needs no credentials.

mock_provider "aws" {
  # Generated strings are not JSON, and the provider validates policy JSON at
  # plan time, so every policy document reads as an empty policy.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

# The VPC module indexes into the AZ list, which the mock would leave empty.
override_data {
  target = data.aws_availability_zones.available
  values = {
    names = ["us-east-1a", "us-east-1b", "us-east-1c"]
  }
}

# Fixture values for every root variable without a usable default. Run blocks
# override only what they toggle.
variables {
  app_prefix                 = "fixture"
  civiform_mode              = "staging"
  ssl_certificate_arn        = "arn:aws:acm:us-east-1:000000000000:certificate/00000000-0000-0000-0000-000000000000"
  fargate_desired_task_count = 1

  # These default to null, but they feed a for_each set in main.tf, and a set
  # cannot hold null, so the root does not plan without them.
  sender_email_address                            = "noreply@fixture.example"
  staging_applicant_notification_mailing_list     = "applicants@fixture.example"
  staging_ti_notification_mailing_list            = "ti@fixture.example"
  staging_program_admin_notification_mailing_list = "admins@fixture.example"
}

# ---------------------------------------------------------------------------
# Prod guardrails: the locals in main.tf and secrets.tf that protect prod data
# ---------------------------------------------------------------------------

run "prod_protects_data" {
  command = plan

  variables {
    civiform_mode = "prod"
  }

  assert {
    condition     = aws_db_instance.civiform.deletion_protection == true
    error_message = "prod DB instance must have deletion protection on"
  }

  assert {
    condition     = aws_db_instance.civiform.skip_final_snapshot == false
    error_message = "prod DB instance must keep a final snapshot"
  }

  assert {
    condition     = aws_db_instance.civiform.final_snapshot_identifier == "fixture-civiform-db-finalsnapshot"
    error_message = "prod final snapshot must be named from the app prefix"
  }

  assert {
    condition     = aws_s3_bucket.civiform_files_s3.force_destroy == false
    error_message = "prod applicant files bucket must not be force-destroyable"
  }

  assert {
    condition     = aws_s3_bucket.civiform_public_files_s3.force_destroy == false && aws_s3_bucket.log_bucket.force_destroy == false
    error_message = "prod public files and log buckets must not be force-destroyable"
  }

  assert {
    condition = alltrue([
      for secret in [
        aws_secretsmanager_secret.postgres_username_secret,
        aws_secretsmanager_secret.postgres_password_secret,
        aws_secretsmanager_secret.app_secret_key_secret,
        aws_secretsmanager_secret.api_secret_salt_secret,
        aws_secretsmanager_secret.adfs_secret_secret,
        aws_secretsmanager_secret.adfs_client_id_secret,
        aws_secretsmanager_secret.applicant_oidc_client_secret_secret,
        aws_secretsmanager_secret.applicant_oidc_client_id_secret,
        aws_secretsmanager_secret.admin_oidc_client_secret_secret,
        aws_secretsmanager_secret.admin_oidc_client_id_secret,
        aws_secretsmanager_secret.esri_arcgis_api_token_secret,
      ] : secret.recovery_window_in_days == 30
    ])
    error_message = "prod secrets must keep the 30-day recovery window"
  }
}

run "staging_is_disposable" {
  command = plan

  variables {
    civiform_mode = "staging"
  }

  assert {
    condition     = aws_db_instance.civiform.deletion_protection == false
    error_message = "staging DB instance must be deletable"
  }

  assert {
    condition     = aws_db_instance.civiform.skip_final_snapshot == true
    error_message = "staging DB instance must skip the final snapshot"
  }

  assert {
    condition     = aws_s3_bucket.civiform_files_s3.force_destroy == true
    error_message = "staging applicant files bucket must be force-destroyable"
  }

  assert {
    condition     = aws_s3_bucket.civiform_public_files_s3.force_destroy == true && aws_s3_bucket.log_bucket.force_destroy == true
    error_message = "staging public files and log buckets must be force-destroyable"
  }

  assert {
    condition = alltrue([
      for secret in [
        aws_secretsmanager_secret.postgres_username_secret,
        aws_secretsmanager_secret.postgres_password_secret,
        aws_secretsmanager_secret.app_secret_key_secret,
        aws_secretsmanager_secret.api_secret_salt_secret,
        aws_secretsmanager_secret.adfs_secret_secret,
        aws_secretsmanager_secret.adfs_client_id_secret,
        aws_secretsmanager_secret.applicant_oidc_client_secret_secret,
        aws_secretsmanager_secret.applicant_oidc_client_id_secret,
        aws_secretsmanager_secret.admin_oidc_client_secret_secret,
        aws_secretsmanager_secret.admin_oidc_client_id_secret,
        aws_secretsmanager_secret.esri_arcgis_api_token_secret,
      ] : secret.recovery_window_in_days == 0
    ])
    error_message = "staging secrets must be deletable immediately"
  }
}

# ---------------------------------------------------------------------------
# VPC mode: managed VPC module vs. externally managed VPC
# ---------------------------------------------------------------------------

run "managed_vpc_is_the_default" {
  command = plan

  assert {
    condition     = length(module.vpc) == 1
    error_message = "the managed VPC module must be created when no external VPC is given"
  }

  assert {
    condition     = length(data.aws_vpc.external) == 0 && length(data.aws_db_subnet_group.external) == 0
    error_message = "no external VPC data sources in managed mode"
  }

  assert {
    condition     = alltrue([for rule in aws_security_group.rds.ingress : try(length(rule.security_groups), 0) == 0])
    error_message = "the RDS security group must not carry an ECS-tasks ingress rule in managed mode"
  }
}

run "external_vpc_disables_managed_vpc" {
  command = plan

  variables {
    external_vpc_id                         = "vpc-00000000000000000"
    external_vpc_database_subnet_group_name = "fixture-db-subnet-group"
    external_vpc_private_subnet_ids         = ["subnet-00000000000000001", "subnet-00000000000000002"]
    external_vpc_public_subnet_ids          = ["subnet-00000000000000011", "subnet-00000000000000012"]

    # TODO(plans/list.md item 7): main.tf passes local.vpc_public_subnets[0]
    # to the dbaccess module, which in external mode is an aws_subnets data
    # object rather than a subnet ID, so the plan fails as soon as dbaccess is
    # on. Flip this to true and uncomment the assertion below once fixed.
    dbaccess = false
    # dbaccess = true
    # dbaccess_cidr_allowlist = ["203.0.113.0/24"]
    # dbaccess_public_key     = "tests/fixtures/dbaccess_key.pub"
  }

  # Pins the ECS tasks security group ID so the RDS ingress set is fully known
  # at plan time; a set with any unknown element is unknown as a whole.
  override_resource {
    target          = module.ecs_fargate_service.aws_security_group.ecs_tasks_sg
    override_during = plan
    values = {
      id = "sg-ecs-tasks"
    }
  }

  assert {
    condition     = length(module.vpc) == 0
    error_message = "the managed VPC module must not be created when all four external VPC variables are set"
  }

  assert {
    condition     = length(data.aws_vpc.external) == 1 && length(data.aws_db_subnet_group.external) == 1
    error_message = "external VPC data sources must be read in external mode"
  }

  assert {
    condition     = anytrue([for rule in aws_security_group.rds.ingress : try(contains(rule.security_groups, "sg-ecs-tasks"), false)])
    error_message = "the RDS security group must allow ingress from the ECS tasks security group in external mode"
  }

  # TODO(plans/list.md item 7): dbaccess exposes only host_private_ip, which
  # is computed, so the subnet ID it receives is not visible from the root.
  # The module planning at all in external mode is the proof it got a string
  # (local.vpc_public_subnet_ids[0], "subnet-00000000000000011") instead of
  # the data object. Uncomment with the dbaccess variables above once fixed.
  # assert {
  #   condition     = length(module.dbaccess) == 1
  #   error_message = "dbaccess must plan in external VPC mode"
  # }
}

# ---------------------------------------------------------------------------
# Toggles: pgadmin and dbaccess, in managed VPC mode
# ---------------------------------------------------------------------------

run "pgadmin_and_dbaccess_are_off_by_default" {
  command = plan

  assert {
    condition     = length(module.pgadmin) == 0
    error_message = "pgadmin module must have count 0 by default"
  }

  assert {
    condition     = length(module.dbaccess) == 0
    error_message = "dbaccess module must have count 0 by default"
  }
}

run "pgadmin_enabled" {
  command = plan

  variables {
    pgadmin                = true
    pgadmin_cidr_allowlist = ["203.0.113.0/24"]
  }

  assert {
    condition     = length(module.pgadmin) == 1
    error_message = "pgadmin module must have count 1 when enabled"
  }
}

run "dbaccess_enabled" {
  command = plan

  variables {
    dbaccess                = true
    dbaccess_cidr_allowlist = ["203.0.113.0/24"]
    # Relative to the root directory, which is where terraform test runs. A
    # throwaway key whose private half was discarded.
    dbaccess_public_key = "tests/fixtures/dbaccess_key.pub"
  }

  assert {
    condition     = length(module.dbaccess) == 1
    error_message = "dbaccess module must have count 1 when enabled"
  }
}

# ---------------------------------------------------------------------------
# Memory preconditions on the validate_* outputs in variables.tf
# ---------------------------------------------------------------------------

run "containers_filling_task_memory_exactly_pass" {
  command = plan

  variables {
    ecs_task_memory                                  = 6144
    ecs_server_container_memory                      = 4096
    ecs_metrics_scraper_container_memory             = 2048
    ecs_server_container_memory_reservation          = 2048
    ecs_metrics_scraper_container_memory_reservation = 1024
  }

  assert {
    condition     = var.ecs_server_container_memory + var.ecs_metrics_scraper_container_memory == var.ecs_task_memory
    error_message = "this run block is meant to sit exactly at the task memory boundary"
  }
}

run "containers_exceeding_task_memory_fail" {
  command = plan

  variables {
    ecs_task_memory                      = 6144
    ecs_server_container_memory          = 4097
    ecs_metrics_scraper_container_memory = 2048
  }

  expect_failures = [
    output.validate_container_memory,
  ]
}

run "server_reservation_not_below_server_memory_fails" {
  command = plan

  variables {
    ecs_server_container_memory             = 4096
    ecs_server_container_memory_reservation = 4096
  }

  expect_failures = [
    output.validate_server_memory_reservation,
  ]
}

run "scraper_reservation_not_below_scraper_memory_fails" {
  command = plan

  variables {
    ecs_metrics_scraper_container_memory             = 2048
    ecs_metrics_scraper_container_memory_reservation = 2048
  }

  expect_failures = [
    output.validate_metrics_scraper_memory_reservation,
  ]
}

# ---------------------------------------------------------------------------
# Alarms: actions wiring, dimensions, and per-alarm toggles
# ---------------------------------------------------------------------------
#
# alarms.tf has ten alarm resources, each count 0/1. The run blocks below
# gather them with concat() so an assertion can sweep every alarm that the
# run block's variables created. The DB-backed dimension values are unknown
# at plan time (the data source waits on the DB resource), but the map keys
# are known, so length() on the dimensions map still works.

run "alarms_without_email_have_no_actions" {
  command = plan

  variables {
    civiform_alarm_email = ""

    rds_create_high_cpu_alarm                  = true
    rds_create_high_queue_depth_alarm          = true
    rds_create_low_disk_space_alarm            = true
    rds_create_low_memory_alarm                = true
    rds_create_low_cpu_credit_alarm            = true
    rds_create_low_disk_burst_alarm            = true
    rds_create_swap_alarm                      = true
    rds_create_anomaly_alarm                   = true
    rds_create_transaction_id_wraparound_alarm = true
    ecs_create_high_memory_alarm               = true
  }

  assert {
    condition     = length(aws_sns_topic.civiform_alert_topic) == 0 && length(aws_sns_topic_subscription.civiform_alert_subscription) == 0
    error_message = "no SNS topic or subscription without an alarm email"
  }

  assert {
    condition = alltrue([
      for alarm in concat(
        aws_cloudwatch_metric_alarm.cpu_utilization_too_high,
        aws_cloudwatch_metric_alarm.cpu_credit_balance_too_low,
        aws_cloudwatch_metric_alarm.disk_queue_depth_too_high,
        aws_cloudwatch_metric_alarm.disk_free_storage_space_too_low,
        aws_cloudwatch_metric_alarm.disk_burst_balance_too_low,
        aws_cloudwatch_metric_alarm.memory_freeable_too_low,
        aws_cloudwatch_metric_alarm.memory_swap_usage_too_high,
        aws_cloudwatch_metric_alarm.connection_count_anomalous,
        aws_cloudwatch_metric_alarm.maximum_used_transaction_ids_too_high,
        aws_cloudwatch_metric_alarm.memory_utilization_too_high,
      ) : length(alarm.alarm_actions) == 0
    ])
    error_message = "every alarm must have empty alarm_actions when no alarm email is set"
  }
}

run "alarms_with_email_have_one_action" {
  command = plan

  variables {
    civiform_alarm_email = "alerts@fixture.example"

    rds_create_high_cpu_alarm                  = true
    rds_create_high_queue_depth_alarm          = true
    rds_create_low_disk_space_alarm            = true
    rds_create_low_memory_alarm                = true
    rds_create_low_cpu_credit_alarm            = true
    rds_create_low_disk_burst_alarm            = true
    rds_create_swap_alarm                      = true
    rds_create_anomaly_alarm                   = true
    rds_create_transaction_id_wraparound_alarm = true
    ecs_create_high_memory_alarm               = true
  }

  assert {
    condition     = length(aws_sns_topic.civiform_alert_topic) == 1 && length(aws_sns_topic_subscription.civiform_alert_subscription) == 1
    error_message = "an alarm email must create one SNS topic and one subscription"
  }

  assert {
    condition     = aws_sns_topic_subscription.civiform_alert_subscription[0].protocol == "email" && aws_sns_topic_subscription.civiform_alert_subscription[0].endpoint == "alerts@fixture.example"
    error_message = "the SNS subscription must email the configured address"
  }

  assert {
    condition = alltrue([
      for alarm in concat(
        aws_cloudwatch_metric_alarm.cpu_utilization_too_high,
        aws_cloudwatch_metric_alarm.cpu_credit_balance_too_low,
        aws_cloudwatch_metric_alarm.disk_queue_depth_too_high,
        aws_cloudwatch_metric_alarm.disk_free_storage_space_too_low,
        aws_cloudwatch_metric_alarm.disk_burst_balance_too_low,
        aws_cloudwatch_metric_alarm.memory_freeable_too_low,
        aws_cloudwatch_metric_alarm.memory_swap_usage_too_high,
        aws_cloudwatch_metric_alarm.connection_count_anomalous,
        aws_cloudwatch_metric_alarm.maximum_used_transaction_ids_too_high,
        aws_cloudwatch_metric_alarm.memory_utilization_too_high,
      ) : length(alarm.alarm_actions) == 1
    ])
    error_message = "every alarm must have exactly one alarm action when an alarm email is set"
  }
}

run "alarms_have_dimensions" {
  command = plan

  variables {
    rds_create_high_cpu_alarm                  = true
    rds_create_high_queue_depth_alarm          = true
    rds_create_low_disk_space_alarm            = true
    rds_create_low_memory_alarm                = true
    rds_create_low_cpu_credit_alarm            = true
    rds_create_low_disk_burst_alarm            = true
    rds_create_swap_alarm                      = true
    rds_create_anomaly_alarm                   = true
    rds_create_transaction_id_wraparound_alarm = true
    ecs_create_high_memory_alarm               = true
  }

  # The anomaly alarm scopes its metric inside metric_query, so its dimensions
  # live there rather than at the top level.
  assert {
    condition = anytrue([
      for query in aws_cloudwatch_metric_alarm.connection_count_anomalous[0].metric_query :
      anytrue([for metric in query.metric : try(length(metric.dimensions), 0) > 0])
    ])
    error_message = "the anomaly alarm's metric must carry dimensions"
  }

  # TODO(plans/list.md item 8): the transaction-ID wraparound alarm has no
  # dimensions block, so it never binds to the DB instance and sits in
  # INSUFFICIENT_DATA. It is left out of the sweep below. Once alarms.tf
  # gives it DBInstanceIdentifier, replace this assertion with the
  # commented-out one that follows it.
  assert {
    condition = alltrue([
      for alarm in concat(
        aws_cloudwatch_metric_alarm.cpu_utilization_too_high,
        aws_cloudwatch_metric_alarm.cpu_credit_balance_too_low,
        aws_cloudwatch_metric_alarm.disk_queue_depth_too_high,
        aws_cloudwatch_metric_alarm.disk_free_storage_space_too_low,
        aws_cloudwatch_metric_alarm.disk_burst_balance_too_low,
        aws_cloudwatch_metric_alarm.memory_freeable_too_low,
        aws_cloudwatch_metric_alarm.memory_swap_usage_too_high,
        aws_cloudwatch_metric_alarm.memory_utilization_too_high,
      ) : try(length(alarm.dimensions), 0) > 0
    ])
    error_message = "every single-metric alarm must have a non-empty dimensions block"
  }
  # assert {
  #   condition = alltrue([
  #     for alarm in concat(
  #       aws_cloudwatch_metric_alarm.cpu_utilization_too_high,
  #       aws_cloudwatch_metric_alarm.cpu_credit_balance_too_low,
  #       aws_cloudwatch_metric_alarm.disk_queue_depth_too_high,
  #       aws_cloudwatch_metric_alarm.disk_free_storage_space_too_low,
  #       aws_cloudwatch_metric_alarm.disk_burst_balance_too_low,
  #       aws_cloudwatch_metric_alarm.memory_freeable_too_low,
  #       aws_cloudwatch_metric_alarm.memory_swap_usage_too_high,
  #       aws_cloudwatch_metric_alarm.maximum_used_transaction_ids_too_high,
  #       aws_cloudwatch_metric_alarm.memory_utilization_too_high,
  #     ) : try(length(alarm.dimensions), 0) > 0
  #   ])
  #   error_message = "every single-metric alarm must have a non-empty dimensions block"
  # }

  # Pins the current state of item 8 so a fix also flips this run block.
  assert {
    condition     = try(length(aws_cloudwatch_metric_alarm.maximum_used_transaction_ids_too_high[0].dimensions), 0) == 0
    error_message = "the transaction-ID wraparound alarm has gained dimensions: plans/list.md item 8 is fixed, swap the assertions above"
  }
}

# Per-alarm toggles. Each run block turns on exactly one rds_create_* variable
# with every other alarm off, and asserts that one alarm, and only that one,
# is created. That catches a toggle wired to the wrong alarm, which an
# all-on/all-off pair would not.

run "all_rds_alarms_off" {
  command = plan

  variables {
    rds_create_high_cpu_alarm                  = false
    rds_create_high_queue_depth_alarm          = false
    rds_create_low_disk_space_alarm            = false
    rds_create_low_memory_alarm                = false
    rds_create_low_cpu_credit_alarm            = false
    rds_create_low_disk_burst_alarm            = false
    rds_create_swap_alarm                      = false
    rds_create_anomaly_alarm                   = false
    rds_create_transaction_id_wraparound_alarm = false
    ecs_create_high_memory_alarm               = false
  }

  assert {
    condition = length(concat(
      aws_cloudwatch_metric_alarm.cpu_utilization_too_high,
      aws_cloudwatch_metric_alarm.cpu_credit_balance_too_low,
      aws_cloudwatch_metric_alarm.disk_queue_depth_too_high,
      aws_cloudwatch_metric_alarm.disk_free_storage_space_too_low,
      aws_cloudwatch_metric_alarm.disk_burst_balance_too_low,
      aws_cloudwatch_metric_alarm.memory_freeable_too_low,
      aws_cloudwatch_metric_alarm.memory_swap_usage_too_high,
      aws_cloudwatch_metric_alarm.connection_count_anomalous,
      aws_cloudwatch_metric_alarm.maximum_used_transaction_ids_too_high,
      aws_cloudwatch_metric_alarm.memory_utilization_too_high,
    )) == 0
    error_message = "no alarms when every toggle is off"
  }
}

run "toggle_rds_create_high_cpu_alarm" {
  command = plan

  variables {
    rds_create_high_cpu_alarm                  = true
    rds_create_high_queue_depth_alarm          = false
    rds_create_low_disk_space_alarm            = false
    rds_create_low_memory_alarm                = false
    rds_create_low_cpu_credit_alarm            = false
    rds_create_low_disk_burst_alarm            = false
    rds_create_swap_alarm                      = false
    rds_create_anomaly_alarm                   = false
    rds_create_transaction_id_wraparound_alarm = false
    ecs_create_high_memory_alarm               = false
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.cpu_utilization_too_high) == 1
    error_message = "rds_create_high_cpu_alarm must create cpu_utilization_too_high"
  }

  assert {
    condition = length(concat(
      aws_cloudwatch_metric_alarm.cpu_credit_balance_too_low,
      aws_cloudwatch_metric_alarm.disk_queue_depth_too_high,
      aws_cloudwatch_metric_alarm.disk_free_storage_space_too_low,
      aws_cloudwatch_metric_alarm.disk_burst_balance_too_low,
      aws_cloudwatch_metric_alarm.memory_freeable_too_low,
      aws_cloudwatch_metric_alarm.memory_swap_usage_too_high,
      aws_cloudwatch_metric_alarm.connection_count_anomalous,
      aws_cloudwatch_metric_alarm.maximum_used_transaction_ids_too_high,
      aws_cloudwatch_metric_alarm.memory_utilization_too_high,
    )) == 0
    error_message = "rds_create_high_cpu_alarm must not create any other alarm"
  }
}

run "toggle_rds_create_high_queue_depth_alarm" {
  command = plan

  variables {
    rds_create_high_cpu_alarm                  = false
    rds_create_high_queue_depth_alarm          = true
    rds_create_low_disk_space_alarm            = false
    rds_create_low_memory_alarm                = false
    rds_create_low_cpu_credit_alarm            = false
    rds_create_low_disk_burst_alarm            = false
    rds_create_swap_alarm                      = false
    rds_create_anomaly_alarm                   = false
    rds_create_transaction_id_wraparound_alarm = false
    ecs_create_high_memory_alarm               = false
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.disk_queue_depth_too_high) == 1
    error_message = "rds_create_high_queue_depth_alarm must create disk_queue_depth_too_high"
  }

  assert {
    condition = length(concat(
      aws_cloudwatch_metric_alarm.cpu_utilization_too_high,
      aws_cloudwatch_metric_alarm.cpu_credit_balance_too_low,
      aws_cloudwatch_metric_alarm.disk_free_storage_space_too_low,
      aws_cloudwatch_metric_alarm.disk_burst_balance_too_low,
      aws_cloudwatch_metric_alarm.memory_freeable_too_low,
      aws_cloudwatch_metric_alarm.memory_swap_usage_too_high,
      aws_cloudwatch_metric_alarm.connection_count_anomalous,
      aws_cloudwatch_metric_alarm.maximum_used_transaction_ids_too_high,
      aws_cloudwatch_metric_alarm.memory_utilization_too_high,
    )) == 0
    error_message = "rds_create_high_queue_depth_alarm must not create any other alarm"
  }
}

run "toggle_rds_create_low_disk_space_alarm" {
  command = plan

  variables {
    rds_create_high_cpu_alarm                  = false
    rds_create_high_queue_depth_alarm          = false
    rds_create_low_disk_space_alarm            = true
    rds_create_low_memory_alarm                = false
    rds_create_low_cpu_credit_alarm            = false
    rds_create_low_disk_burst_alarm            = false
    rds_create_swap_alarm                      = false
    rds_create_anomaly_alarm                   = false
    rds_create_transaction_id_wraparound_alarm = false
    ecs_create_high_memory_alarm               = false
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.disk_free_storage_space_too_low) == 1
    error_message = "rds_create_low_disk_space_alarm must create disk_free_storage_space_too_low"
  }

  assert {
    condition = length(concat(
      aws_cloudwatch_metric_alarm.cpu_utilization_too_high,
      aws_cloudwatch_metric_alarm.cpu_credit_balance_too_low,
      aws_cloudwatch_metric_alarm.disk_queue_depth_too_high,
      aws_cloudwatch_metric_alarm.disk_burst_balance_too_low,
      aws_cloudwatch_metric_alarm.memory_freeable_too_low,
      aws_cloudwatch_metric_alarm.memory_swap_usage_too_high,
      aws_cloudwatch_metric_alarm.connection_count_anomalous,
      aws_cloudwatch_metric_alarm.maximum_used_transaction_ids_too_high,
      aws_cloudwatch_metric_alarm.memory_utilization_too_high,
    )) == 0
    error_message = "rds_create_low_disk_space_alarm must not create any other alarm"
  }
}

run "toggle_rds_create_low_memory_alarm" {
  command = plan

  variables {
    rds_create_high_cpu_alarm                  = false
    rds_create_high_queue_depth_alarm          = false
    rds_create_low_disk_space_alarm            = false
    rds_create_low_memory_alarm                = true
    rds_create_low_cpu_credit_alarm            = false
    rds_create_low_disk_burst_alarm            = false
    rds_create_swap_alarm                      = false
    rds_create_anomaly_alarm                   = false
    rds_create_transaction_id_wraparound_alarm = false
    ecs_create_high_memory_alarm               = false
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.memory_freeable_too_low) == 1
    error_message = "rds_create_low_memory_alarm must create memory_freeable_too_low"
  }

  assert {
    condition = length(concat(
      aws_cloudwatch_metric_alarm.cpu_utilization_too_high,
      aws_cloudwatch_metric_alarm.cpu_credit_balance_too_low,
      aws_cloudwatch_metric_alarm.disk_queue_depth_too_high,
      aws_cloudwatch_metric_alarm.disk_free_storage_space_too_low,
      aws_cloudwatch_metric_alarm.disk_burst_balance_too_low,
      aws_cloudwatch_metric_alarm.memory_swap_usage_too_high,
      aws_cloudwatch_metric_alarm.connection_count_anomalous,
      aws_cloudwatch_metric_alarm.maximum_used_transaction_ids_too_high,
      aws_cloudwatch_metric_alarm.memory_utilization_too_high,
    )) == 0
    error_message = "rds_create_low_memory_alarm must not create any other alarm"
  }
}

run "toggle_rds_create_low_cpu_credit_alarm" {
  command = plan

  variables {
    # The default db.t3.micro is burstable, which this alarm also requires.
    rds_create_high_cpu_alarm                  = false
    rds_create_high_queue_depth_alarm          = false
    rds_create_low_disk_space_alarm            = false
    rds_create_low_memory_alarm                = false
    rds_create_low_cpu_credit_alarm            = true
    rds_create_low_disk_burst_alarm            = false
    rds_create_swap_alarm                      = false
    rds_create_anomaly_alarm                   = false
    rds_create_transaction_id_wraparound_alarm = false
    ecs_create_high_memory_alarm               = false
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.cpu_credit_balance_too_low) == 1
    error_message = "rds_create_low_cpu_credit_alarm must create cpu_credit_balance_too_low on a burstable class"
  }

  assert {
    condition = length(concat(
      aws_cloudwatch_metric_alarm.cpu_utilization_too_high,
      aws_cloudwatch_metric_alarm.disk_queue_depth_too_high,
      aws_cloudwatch_metric_alarm.disk_free_storage_space_too_low,
      aws_cloudwatch_metric_alarm.disk_burst_balance_too_low,
      aws_cloudwatch_metric_alarm.memory_freeable_too_low,
      aws_cloudwatch_metric_alarm.memory_swap_usage_too_high,
      aws_cloudwatch_metric_alarm.connection_count_anomalous,
      aws_cloudwatch_metric_alarm.maximum_used_transaction_ids_too_high,
      aws_cloudwatch_metric_alarm.memory_utilization_too_high,
    )) == 0
    error_message = "rds_create_low_cpu_credit_alarm must not create any other alarm"
  }
}

run "cpu_credit_alarm_skipped_on_non_burstable_class" {
  command = plan

  variables {
    rds_create_low_cpu_credit_alarm = true
    postgres_instance_class         = "db.m5.large"
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.cpu_credit_balance_too_low) == 0
    error_message = "the CPU credit alarm only applies to t2/t3/t4 instance classes"
  }
}

run "toggle_rds_create_low_disk_burst_alarm" {
  command = plan

  variables {
    rds_create_high_cpu_alarm                  = false
    rds_create_high_queue_depth_alarm          = false
    rds_create_low_disk_space_alarm            = false
    rds_create_low_memory_alarm                = false
    rds_create_low_cpu_credit_alarm            = false
    rds_create_low_disk_burst_alarm            = true
    rds_create_swap_alarm                      = false
    rds_create_anomaly_alarm                   = false
    rds_create_transaction_id_wraparound_alarm = false
    ecs_create_high_memory_alarm               = false
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.disk_burst_balance_too_low) == 1
    error_message = "rds_create_low_disk_burst_alarm must create disk_burst_balance_too_low"
  }

  assert {
    condition = length(concat(
      aws_cloudwatch_metric_alarm.cpu_utilization_too_high,
      aws_cloudwatch_metric_alarm.cpu_credit_balance_too_low,
      aws_cloudwatch_metric_alarm.disk_queue_depth_too_high,
      aws_cloudwatch_metric_alarm.disk_free_storage_space_too_low,
      aws_cloudwatch_metric_alarm.memory_freeable_too_low,
      aws_cloudwatch_metric_alarm.memory_swap_usage_too_high,
      aws_cloudwatch_metric_alarm.connection_count_anomalous,
      aws_cloudwatch_metric_alarm.maximum_used_transaction_ids_too_high,
      aws_cloudwatch_metric_alarm.memory_utilization_too_high,
    )) == 0
    error_message = "rds_create_low_disk_burst_alarm must not create any other alarm"
  }
}

run "toggle_rds_create_swap_alarm" {
  command = plan

  variables {
    rds_create_high_cpu_alarm                  = false
    rds_create_high_queue_depth_alarm          = false
    rds_create_low_disk_space_alarm            = false
    rds_create_low_memory_alarm                = false
    rds_create_low_cpu_credit_alarm            = false
    rds_create_low_disk_burst_alarm            = false
    rds_create_swap_alarm                      = true
    rds_create_anomaly_alarm                   = false
    rds_create_transaction_id_wraparound_alarm = false
    ecs_create_high_memory_alarm               = false
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.memory_swap_usage_too_high) == 1
    error_message = "rds_create_swap_alarm must create memory_swap_usage_too_high"
  }

  assert {
    condition = length(concat(
      aws_cloudwatch_metric_alarm.cpu_utilization_too_high,
      aws_cloudwatch_metric_alarm.cpu_credit_balance_too_low,
      aws_cloudwatch_metric_alarm.disk_queue_depth_too_high,
      aws_cloudwatch_metric_alarm.disk_free_storage_space_too_low,
      aws_cloudwatch_metric_alarm.disk_burst_balance_too_low,
      aws_cloudwatch_metric_alarm.memory_freeable_too_low,
      aws_cloudwatch_metric_alarm.connection_count_anomalous,
      aws_cloudwatch_metric_alarm.maximum_used_transaction_ids_too_high,
      aws_cloudwatch_metric_alarm.memory_utilization_too_high,
    )) == 0
    error_message = "rds_create_swap_alarm must not create any other alarm"
  }
}

run "toggle_rds_create_anomaly_alarm" {
  command = plan

  variables {
    rds_create_high_cpu_alarm                  = false
    rds_create_high_queue_depth_alarm          = false
    rds_create_low_disk_space_alarm            = false
    rds_create_low_memory_alarm                = false
    rds_create_low_cpu_credit_alarm            = false
    rds_create_low_disk_burst_alarm            = false
    rds_create_swap_alarm                      = false
    rds_create_anomaly_alarm                   = true
    rds_create_transaction_id_wraparound_alarm = false
    ecs_create_high_memory_alarm               = false
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.connection_count_anomalous) == 1
    error_message = "rds_create_anomaly_alarm must create connection_count_anomalous"
  }

  assert {
    condition = length(concat(
      aws_cloudwatch_metric_alarm.cpu_utilization_too_high,
      aws_cloudwatch_metric_alarm.cpu_credit_balance_too_low,
      aws_cloudwatch_metric_alarm.disk_queue_depth_too_high,
      aws_cloudwatch_metric_alarm.disk_free_storage_space_too_low,
      aws_cloudwatch_metric_alarm.disk_burst_balance_too_low,
      aws_cloudwatch_metric_alarm.memory_freeable_too_low,
      aws_cloudwatch_metric_alarm.memory_swap_usage_too_high,
      aws_cloudwatch_metric_alarm.maximum_used_transaction_ids_too_high,
      aws_cloudwatch_metric_alarm.memory_utilization_too_high,
    )) == 0
    error_message = "rds_create_anomaly_alarm must not create any other alarm"
  }
}

run "toggle_rds_create_transaction_id_wraparound_alarm" {
  command = plan

  variables {
    rds_create_high_cpu_alarm                  = false
    rds_create_high_queue_depth_alarm          = false
    rds_create_low_disk_space_alarm            = false
    rds_create_low_memory_alarm                = false
    rds_create_low_cpu_credit_alarm            = false
    rds_create_low_disk_burst_alarm            = false
    rds_create_swap_alarm                      = false
    rds_create_anomaly_alarm                   = false
    rds_create_transaction_id_wraparound_alarm = true
    ecs_create_high_memory_alarm               = false
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.maximum_used_transaction_ids_too_high) == 1
    error_message = "rds_create_transaction_id_wraparound_alarm must create maximum_used_transaction_ids_too_high"
  }

  assert {
    condition = length(concat(
      aws_cloudwatch_metric_alarm.cpu_utilization_too_high,
      aws_cloudwatch_metric_alarm.cpu_credit_balance_too_low,
      aws_cloudwatch_metric_alarm.disk_queue_depth_too_high,
      aws_cloudwatch_metric_alarm.disk_free_storage_space_too_low,
      aws_cloudwatch_metric_alarm.disk_burst_balance_too_low,
      aws_cloudwatch_metric_alarm.memory_freeable_too_low,
      aws_cloudwatch_metric_alarm.memory_swap_usage_too_high,
      aws_cloudwatch_metric_alarm.connection_count_anomalous,
      aws_cloudwatch_metric_alarm.memory_utilization_too_high,
    )) == 0
    error_message = "rds_create_transaction_id_wraparound_alarm must not create any other alarm"
  }
}

run "toggle_ecs_create_high_memory_alarm" {
  command = plan

  variables {
    rds_create_high_cpu_alarm                  = false
    rds_create_high_queue_depth_alarm          = false
    rds_create_low_disk_space_alarm            = false
    rds_create_low_memory_alarm                = false
    rds_create_low_cpu_credit_alarm            = false
    rds_create_low_disk_burst_alarm            = false
    rds_create_swap_alarm                      = false
    rds_create_anomaly_alarm                   = false
    rds_create_transaction_id_wraparound_alarm = false
    ecs_create_high_memory_alarm               = true
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.memory_utilization_too_high) == 1
    error_message = "ecs_create_high_memory_alarm must create memory_utilization_too_high"
  }

  assert {
    condition = length(concat(
      aws_cloudwatch_metric_alarm.cpu_utilization_too_high,
      aws_cloudwatch_metric_alarm.cpu_credit_balance_too_low,
      aws_cloudwatch_metric_alarm.disk_queue_depth_too_high,
      aws_cloudwatch_metric_alarm.disk_free_storage_space_too_low,
      aws_cloudwatch_metric_alarm.disk_burst_balance_too_low,
      aws_cloudwatch_metric_alarm.memory_freeable_too_low,
      aws_cloudwatch_metric_alarm.memory_swap_usage_too_high,
      aws_cloudwatch_metric_alarm.connection_count_anomalous,
      aws_cloudwatch_metric_alarm.maximum_used_transaction_ids_too_high,
    )) == 0
    error_message = "ecs_create_high_memory_alarm must not create any other alarm"
  }
}
