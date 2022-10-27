# Create a random generated password to use for pgadmin default email.
resource "random_password" "pgadmin_username" {
  length  = 10
  special = false
  keepers = {
    version = 1
  }
}
resource "aws_secretsmanager_secret" "pgadmin_username_secret" {
  name                    = "${var.app_prefix}-civiform_pgadmin_default_username"
  kms_key_id              = var.secrets_kms_key_arn
  recovery_window_in_days = var.secrets_recovery_window_in_days
  tags = {
    Name = "${var.app_prefix} Civiform pgAdmin Username"
    Type = "Civiform pgAdmin Username"
  }
}
resource "aws_secretsmanager_secret_version" "pgadmin_username_secret_version" {
  secret_id     = aws_secretsmanager_secret.pgadmin_username_secret.id
  secret_string = "${random_password.pgadmin_username.result}@default.login"
}

# Create a random generated password to use for pgadmin password.
resource "random_password" "pgadmin_password" {
  length  = 40
  special = false
  keepers = {
    version = 1
  }
}
resource "aws_secretsmanager_secret" "pgadmin_password_secret" {
  name                    = "${var.app_prefix}-civiform_pgadmin_default_password"
  kms_key_id              = var.secrets_kms_key_arn
  recovery_window_in_days = var.secrets_recovery_window_in_days
  tags = {
    Name = "${var.app_prefix} Civiform pgAdmin Password Secret"
    Type = "Civiform pgAdmin Password Secret"
  }
}
resource "aws_secretsmanager_secret_version" "pgadmin_password_secret_version" {
  secret_id     = aws_secretsmanager_secret.pgadmin_password_secret.id
  secret_string = random_password.pgadmin_password.result
}
