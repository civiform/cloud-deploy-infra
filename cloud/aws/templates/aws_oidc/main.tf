locals {
  # Make db deletable on staging.
  deletion_protection = var.civiform_mode == "prod" ? true : false
  skip_final_snapshot = var.civiform_mode == "prod" ? false : true
  force_destroy_s3    = var.civiform_mode == "prod" ? false : true
}

# TODO: split this into modules.
# List of params that we could configure:
# https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Appendix.PostgreSQL.CommonDBATasks.Parameters.html#Appendix.PostgreSQL.CommonDBATasks.Parameters.parameters-list
resource "aws_db_parameter_group" "civiform" {
  name = "${var.app_prefix}-civiform-db-params"
  tags = {
    Name = "${var.app_prefix} Civiform DB Parameters"
    Type = "Civiform DB Parameters"
  }

  family = "postgres12"

  parameter {
    name  = "log_connections"
    value = "1"
  }
}

resource "aws_db_instance" "civiform" {
  identifier = "${var.app_prefix}-${var.postgress_name}-db"
  tags = {
    Name = "${var.app_prefix} Civiform Database"
    Type = "Civiform Database"
  }

  # If not null, destroys the current database, replacing it with a new one restored from the provided snapshot
  snapshot_identifier             = var.postgres_restore_snapshot_identifier
  deletion_protection             = local.deletion_protection
  instance_class                  = var.postgres_instance_class
  allocated_storage               = var.postgres_storage_gb
  engine                          = "postgres"
  engine_version                  = "12"
  username                        = aws_secretsmanager_secret_version.postgres_username_secret_version.secret_string
  password                        = aws_secretsmanager_secret_version.postgres_password_secret_version.secret_string
  vpc_security_group_ids          = [aws_security_group.rds.id]
  db_subnet_group_name            = module.vpc.database_subnet_group_name
  parameter_group_name            = aws_db_parameter_group.civiform.name
  publicly_accessible             = false
  skip_final_snapshot             = local.skip_final_snapshot
  final_snapshot_identifier       = "${var.app_prefix}-civiform-db-finalsnapshot"
  backup_retention_period         = var.postgres_backup_retention_days
  kms_key_id                      = aws_kms_key.civiform_kms_key.arn
  storage_encrypted               = true
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
}

# Provide database information for other resources (pgadmin, for example).
data "aws_db_instance" "civiform" {
  db_instance_identifier = "${var.app_prefix}-${var.postgress_name}-db"
  depends_on = [
    aws_db_instance.civiform
  ]
}

module "email_service" {
  for_each = toset([
    var.sender_email_address,
    var.staging_applicant_notification_mailing_list,
    var.staging_ti_notification_mailing_list,
    var.staging_program_admin_notification_mailing_list
  ])
  source               = "../../modules/ses"
  sender_email_address = each.key
}

module "pgadmin" {
  source = "../../modules/pgadmin"
  count  = var.pgadmin ? 1 : 0

  app_prefix = var.app_prefix
  aws_region = var.aws_region

  vpc_id          = module.vpc.vpc_id
  lb_arn          = module.ecs_fargate_service.aws_lb_lb_arn
  lb_ssl_cert_arn = var.ssl_certificate_arn
  lb_access_sg_id = module.ecs_fargate_service.aws_security_group_lb_access_sg_id
  cidr_allowlist  = var.pgadmin_cidr_allowlist

  ecs_cluster_arn = module.ecs_cluster.aws_ecs_cluster_cluster_arn
  subnet_ids      = module.vpc.private_subnets

  db_sg_id               = aws_security_group.rds.id
  db_address             = data.aws_db_instance.civiform.address
  db_port                = data.aws_db_instance.civiform.port
  db_username_secret_arn = aws_secretsmanager_secret_version.postgres_username_secret_version.arn

  secrets_kms_key_arn             = aws_kms_key.civiform_kms_key.arn
  secrets_recovery_window_in_days = local.secret_recovery_window_in_days
}
