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
  name_prefix = "${var.app_prefix}-civiform-db-params"
  tags = {
    Name = "${var.app_prefix} Civiform DB Parameters"
    Type = "Civiform DB Parameters"
  }

  family = "postgres${split(".", var.postgresql_version)[0]}"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_instance" "civiform" {
  identifier = "${var.app_prefix}-${var.postgress_name}-db"
  tags = {
    Name = "${var.app_prefix} Civiform Database"
    Type = "Civiform Database"
  }

  apply_immediately = var.apply_database_changes_immediately

  # If not null, destroys the current database, replacing it with a new one restored from the provided snapshot
  snapshot_identifier             = var.postgres_restore_snapshot_identifier
  deletion_protection             = local.deletion_protection
  instance_class                  = var.postgres_instance_class
  allocated_storage               = var.postgres_storage_gb
  max_allocated_storage           = var.postgres_max_allocated_storage_gb
  storage_type                    = var.aws_db_storage_type
  storage_throughput              = var.aws_db_storage_throughput
  iops                            = var.aws_db_iops
  engine                          = "postgres"
  engine_version                  = var.postgresql_version
  allow_major_version_upgrade     = var.allow_postgresql_upgrade
  username                        = aws_secretsmanager_secret_version.postgres_username_secret_version.secret_string
  password                        = aws_secretsmanager_secret_version.postgres_password_secret_version.secret_string
  vpc_security_group_ids          = [aws_security_group.rds.id]
  db_subnet_group_name            = local.vpc_database_subnet_group_name
  parameter_group_name            = aws_db_parameter_group.civiform.name
  publicly_accessible             = false
  skip_final_snapshot             = local.skip_final_snapshot
  final_snapshot_identifier       = "${var.app_prefix}-civiform-db-finalsnapshot"
  backup_retention_period         = var.postgres_backup_retention_days
  kms_key_id                      = aws_kms_key.civiform_kms_key.arn
  storage_encrypted               = true
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  performance_insights_enabled    = var.rds_performance_insights_enabled
  monitoring_role_arn             = var.rds_enhanced_monitoring_enabled ? aws_iam_role.civiform_enhanced_monitoring_role[0].arn : null
  monitoring_interval             = var.rds_enhanced_monitoring_enabled ? var.rds_enhanced_monitoring_interval : null
}

# Provide database information for other resources (pgadmin, for example).
data "aws_db_instance" "civiform" {
  db_instance_identifier = "${var.app_prefix}-${var.postgress_name}-db"
  depends_on = [
    aws_db_instance.civiform
  ]
}

# IAM Role for RDS Enhanced Monitoring
resource "aws_iam_role" "civiform_enhanced_monitoring_role" {
  count = var.rds_enhanced_monitoring_enabled ? 1 : 0
  name  = "civiform_enhanced_monitoring_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      },
    ]
  })

  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"]

  tags = {
    Name = "civiform_enhanced_monitoring_role"
  }
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

# Security group for managing access to the database
resource "aws_security_group" "rds" {
  tags = {
    Name = "${var.app_prefix} Civiform DB Security Group"
    Type = "Civiform DB Security Group"
  }
  name   = "${var.app_prefix}-civiform_rds"
  vpc_id = local.vpc_id

  ingress {
    from_port = 5432
    to_port   = 5432
    protocol  = "tcp"
    # Only apps within VPCs can access the database.
    cidr_blocks = var.private_subnets
  }

  dynamic "ingress" {
    for_each = var.dbaccess ? [module.dbaccess[0].host_private_ip] : []
    # Rather than specifying source_security_group_id, we use the private IP of the dbaccess instance.
    # Otherwise, we create a dependency between the dbaccess module and this resource and 
    # Terraform doesn't necessarily remove this rule before removing the dbaccess security group,
    # which causes a failure when attempting to remove the dbaccess security group.
    content {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      cidr_blocks = ["${ingress.value}/32"]
    }
  }

  dynamic "ingress" {
    for_each = local.enable_managed_vpc ? [] : [1]
    # If the VPC is managed outside of terraform, we need to ensure that the tasks have access to the database to make connections
    content {
      from_port       = 5432
      to_port         = 5432
      protocol        = "tcp"
      security_groups = [module.ecs_fargate_service.aws_security_group_ecs_tasks_access_sg_id]
    }
  }
}

module "pgadmin" {
  source = "../../modules/pgadmin"
  count  = var.pgadmin ? 1 : 0

  app_prefix = var.app_prefix
  aws_region = var.aws_region

  vpc_id          = local.vpc_id
  lb_arn          = module.ecs_fargate_service.aws_lb_civiform_lb_arn
  lb_ssl_cert_arn = var.ssl_certificate_arn
  lb_access_sg_id = module.ecs_fargate_service.aws_security_group_lb_access_sg_id
  cidr_allowlist  = var.pgadmin_cidr_allowlist

  ecs_cluster_arn = module.ecs_cluster.aws_ecs_cluster_cluster_arn
  subnet_ids      = local.vpc_private_subnet_ids

  db_sg_id               = aws_security_group.rds.id
  db_address             = data.aws_db_instance.civiform.address
  db_port                = data.aws_db_instance.civiform.port
  db_username_secret_arn = aws_secretsmanager_secret_version.postgres_username_secret_version.arn

  secrets_kms_key_arn             = aws_kms_key.civiform_kms_key.arn
  secrets_recovery_window_in_days = local.secret_recovery_window_in_days
}

module "dbaccess" {
  source = "../../modules/dbaccess"
  count  = var.dbaccess ? 1 : 0

  app_prefix = var.app_prefix
  aws_region = var.aws_region

  vpc_id         = local.vpc_id
  cidr_allowlist = var.dbaccess_cidr_allowlist
  db_sg_id       = aws_security_group.rds.id
  public_key     = var.dbaccess_public_key
  public_subnet  = local.vpc_public_subnets[0]
}
