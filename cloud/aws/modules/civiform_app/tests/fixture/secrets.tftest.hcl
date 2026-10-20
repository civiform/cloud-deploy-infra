# Plan-only suite for civiform_app: the no-drift promise on the secrets list.
#
# Every run block plans the module itself (module source "../../") against a
# mocked aws provider: no credentials, no backend, no state. Planning the
# module directly is what lets assertions and expect_failures address its
# resources; from a root, only a child module's outputs are visible.
#
# Every input the module consumes is a plain string passed in here, so the
# container definitions and the IAM policy document are fully known at plan
# time and can be jsondecode()d in assertions.

mock_provider "aws" {}

# Inputs shared by every run block. Individual run blocks override only what
# they exercise.
variables {
  app_prefix = "fixture"
  aws_region = "us-east-1"

  log_group_name         = "fixture-civiformlogs/"
  scraper_log_group_name = "fixture-civiform-scraper-logs/"

  secrets = [
    {
      name       = "DB_USERNAME"
      value_arn  = "arn:aws:secretsmanager:us-east-1:000000000000:secret:fixture-db-username-AAAAAA:v1"
      secret_arn = "arn:aws:secretsmanager:us-east-1:000000000000:secret:fixture-db-username-AAAAAA"
    },
    {
      name       = "DB_PASSWORD"
      value_arn  = "arn:aws:secretsmanager:us-east-1:000000000000:secret:fixture-db-password-BBBBBB:v1"
      secret_arn = "arn:aws:secretsmanager:us-east-1:000000000000:secret:fixture-db-password-BBBBBB"
    },
    {
      name       = "SECRET_KEY"
      value_arn  = "arn:aws:secretsmanager:us-east-1:000000000000:secret:fixture-secret-key-CCCCCC:v1"
      secret_arn = "arn:aws:secretsmanager:us-east-1:000000000000:secret:fixture-secret-key-CCCCCC"
    },
  ]
  db_jdbc_string                  = "jdbc:postgresql://db.fixture.internal:5432/postgres?ssl=true&sslmode=require"
  file_storage_bucket_name        = "fixture-civiform-files-s3"
  file_storage_bucket_arn         = "arn:aws:s3:::fixture-civiform-files-s3"
  public_file_storage_bucket_name = "fixture-civiform-public-files-s3"
  kms_key_arns                    = ["arn:aws:kms:us-east-1:000000000000:key/00000000-0000-0000-0000-000000000000"]
}

run "secrets_feed_container_and_policy_in_order" {
  command = plan

  module {
    source = "../../"
  }

  # Server container is element 0 in both task definitions.
  #
  # The cloudposse container definition module keys secrets by name and emits
  # them in lexical order, so the array is sorted by name regardless of the
  # order the list was passed in (plans/list.md item 59 tracks the module
  # docs, which claim the caller's order is preserved).
  assert {
    condition     = jsondecode(aws_ecs_task_definition.civiform_only.container_definitions)[0].secrets[*].name == ["DB_PASSWORD", "DB_USERNAME", "SECRET_KEY"]
    error_message = "civiform_only container secrets must be the three names, sorted by name"
  }

  assert {
    condition     = jsondecode(aws_ecs_task_definition.civiform_with_monitoring.container_definitions)[0].secrets[*].name == ["DB_PASSWORD", "DB_USERNAME", "SECRET_KEY"]
    error_message = "civiform_with_monitoring container secrets must be the three names, sorted by name"
  }

  assert {
    condition = jsondecode(aws_ecs_task_definition.civiform_only.container_definitions)[0].secrets[*].valueFrom == [
      "arn:aws:secretsmanager:us-east-1:000000000000:secret:fixture-db-password-BBBBBB:v1",
      "arn:aws:secretsmanager:us-east-1:000000000000:secret:fixture-db-username-AAAAAA:v1",
      "arn:aws:secretsmanager:us-east-1:000000000000:secret:fixture-secret-key-CCCCCC:v1",
    ]
    error_message = "container secrets must reference the secret version ARNs, paired with their names"
  }

  # The scraper container carries no secrets.
  assert {
    condition     = try(length(jsondecode(aws_ecs_task_definition.civiform_with_monitoring.container_definitions)[1].secrets), 0) == 0
    error_message = "the metrics scraper container must not receive the secrets"
  }

  # Exactly one statement grants GetSecretValue, and it names exactly the
  # three secret ARNs.
  assert {
    condition = length([
      for statement in jsondecode(aws_iam_policy.civiform_ecs_task_execution_role_custom_policy[0].policy).Statement :
      statement if contains(statement.Action, "secretsmanager:GetSecretValue")
    ]) == 1
    error_message = "exactly one policy statement must grant secretsmanager:GetSecretValue"
  }

  assert {
    condition = one([
      for statement in jsondecode(aws_iam_policy.civiform_ecs_task_execution_role_custom_policy[0].policy).Statement :
      statement.Resource if contains(statement.Action, "secretsmanager:GetSecretValue")
      ]) == [
      "arn:aws:secretsmanager:us-east-1:000000000000:secret:fixture-db-username-AAAAAA",
      "arn:aws:secretsmanager:us-east-1:000000000000:secret:fixture-db-password-BBBBBB",
      "arn:aws:secretsmanager:us-east-1:000000000000:secret:fixture-secret-key-CCCCCC",
    ]
    error_message = "the GetSecretValue statement must grant exactly the three secret ARNs, nothing else"
  }

  # No other statement mentions secretsmanager at all.
  assert {
    condition = length([
      for statement in jsondecode(aws_iam_policy.civiform_ecs_task_execution_role_custom_policy[0].policy).Statement :
      statement if anytrue([for action in statement.Action : startswith(action, "secretsmanager:")]) && !contains(statement.Action, "secretsmanager:GetSecretValue")
    ]) == 0
    error_message = "no statement other than the GetSecretValue one may grant secretsmanager actions"
  }
}

run "secrets_order_does_not_change_the_container_definition" {
  command = plan

  module {
    source = "../../"
  }

  # Same three secrets as the file-level block, passed in reverse.
  variables {
    secrets = [
      {
        name       = "SECRET_KEY"
        value_arn  = "arn:aws:secretsmanager:us-east-1:000000000000:secret:fixture-secret-key-CCCCCC:v1"
        secret_arn = "arn:aws:secretsmanager:us-east-1:000000000000:secret:fixture-secret-key-CCCCCC"
      },
      {
        name       = "DB_PASSWORD"
        value_arn  = "arn:aws:secretsmanager:us-east-1:000000000000:secret:fixture-db-password-BBBBBB:v1"
        secret_arn = "arn:aws:secretsmanager:us-east-1:000000000000:secret:fixture-db-password-BBBBBB"
      },
      {
        name       = "DB_USERNAME"
        value_arn  = "arn:aws:secretsmanager:us-east-1:000000000000:secret:fixture-db-username-AAAAAA:v1"
        secret_arn = "arn:aws:secretsmanager:us-east-1:000000000000:secret:fixture-db-username-AAAAAA"
      },
    ]
  }

  assert {
    condition     = jsondecode(aws_ecs_task_definition.civiform_only.container_definitions)[0].secrets[*].name == ["DB_PASSWORD", "DB_USERNAME", "SECRET_KEY"]
    error_message = "reordering the secrets list must not change the container definition's secrets array"
  }

  # The IAM statement, by contrast, follows the list order.
  assert {
    condition = one([
      for statement in jsondecode(aws_iam_policy.civiform_ecs_task_execution_role_custom_policy[0].policy).Statement :
      statement.Resource if contains(statement.Action, "secretsmanager:GetSecretValue")
      ]) == [
      "arn:aws:secretsmanager:us-east-1:000000000000:secret:fixture-secret-key-CCCCCC",
      "arn:aws:secretsmanager:us-east-1:000000000000:secret:fixture-db-password-BBBBBB",
      "arn:aws:secretsmanager:us-east-1:000000000000:secret:fixture-db-username-AAAAAA",
    ]
    error_message = "the GetSecretValue statement must still grant exactly the three secret ARNs"
  }
}

run "kms_statement_lists_exactly_the_given_key" {
  command = plan

  module {
    source = "../../"
  }

  variables {
    kms_key_arns = ["arn:aws:kms:us-east-1:000000000000:key/11111111-1111-1111-1111-111111111111"]
  }

  assert {
    condition = one([
      for statement in jsondecode(aws_iam_policy.civiform_ecs_task_execution_role_custom_policy[0].policy).Statement :
      statement.Resource if contains(statement.Action, "kms:Decrypt")
    ]) == ["arn:aws:kms:us-east-1:000000000000:key/11111111-1111-1111-1111-111111111111"]
    error_message = "the KMS statement must list exactly the one key ARN passed in"
  }
}

run "empty_kms_key_list_fails_validation" {
  command = plan

  module {
    source = "../../"
  }

  variables {
    kms_key_arns = []
  }

  expect_failures = [
    var.kms_key_arns,
  ]
}
