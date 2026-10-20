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
