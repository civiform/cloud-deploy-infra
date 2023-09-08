// CPU Utilization
resource "aws_cloudwatch_metric_alarm" "cpu_utilization_too_high" {
  count               = var.rds_create_high_cpu_alarm ? 1 : 0
  alarm_name          = "rds-${data.aws_db_instance.civiform.id}-highCPUUtilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.rds_alarm_evaluation_period
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = var.rds_alarm_statistic_period
  statistic           = "Average"
  threshold           = var.rds_max_cpu_utilization_threshold
  alarm_description   = "Average database CPU utilization is too high."
  alarm_actions       = [aws_sns_topic.civiform_alert_topic.arn]

  dimensions = {
    DBInstanceIdentifier = data.aws_db_instance.civiform.id
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu_credit_balance_too_low" {
  count               = var.rds_create_low_cpu_credit_alarm ? length(regexall("(t2|t3|t4)", var.postgres_instance_class)) > 0 ? 1 : 0 : 0
  alarm_name          = "rds-${data.aws_db_instance.civiform.id}-lowCPUCreditBalance"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = var.rds_alarm_evaluation_period
  metric_name         = "CPUCreditBalance"
  namespace           = "AWS/RDS"
  period              = var.rds_alarm_statistic_period
  statistic           = "Average"
  threshold           = var.rds_low_cpu_credit_balance_threshold
  alarm_description   = "Average database CPU credit balance is too low, a negative performance impact is imminent. When this alarm triggers, the database [instance class](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.DBInstanceClass.html) should be increased."
  alarm_actions       = [aws_sns_topic.civiform_alert_topic.arn]

  dimensions = {
    DBInstanceIdentifier = data.aws_db_instance.civiform.id
  }
}

// Disk Utilization
resource "aws_cloudwatch_metric_alarm" "disk_queue_depth_too_high" {
  count               = var.rds_create_high_queue_depth_alarm ? 1 : 0
  alarm_name          = "rds-${data.aws_db_instance.civiform.id}-highDiskQueueDepth"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.rds_alarm_evaluation_period
  metric_name         = "DiskQueueDepth"
  namespace           = "AWS/RDS"
  period              = var.rds_alarm_statistic_period
  statistic           = "Average"
  threshold           = var.rds_disk_queue_depth_high_threshold
  alarm_description   = "Average database disk queue depth is too high, performance may be negatively impacted."
  alarm_actions       = [aws_sns_topic.civiform_alert_topic.arn]

  dimensions = {
    DBInstanceIdentifier = data.aws_db_instance.civiform.id
  }
}

resource "aws_cloudwatch_metric_alarm" "disk_free_storage_space_too_low" {
  count               = var.rds_create_low_disk_space_alarm ? 1 : 0
  alarm_name          = "rds-${data.aws_db_instance.civiform.id}-lowFreeStorageSpace"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = var.rds_alarm_evaluation_period
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = var.rds_alarm_statistic_period
  statistic           = "Average"
  threshold           = var.rds_disk_free_storage_low_threshold
  alarm_description   = "Average database free storage space is too low and may fill up soon."
  alarm_actions       = [aws_sns_topic.civiform_alert_topic.arn]

  dimensions = {
    DBInstanceIdentifier = data.aws_db_instance.civiform.id
  }
}

resource "aws_cloudwatch_metric_alarm" "disk_burst_balance_too_low" {
  count               = var.rds_create_low_disk_burst_alarm ? 1 : 0
  alarm_name          = "rds-${data.aws_db_instance.civiform.id}-lowEBSBurstBalance"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = var.rds_alarm_evaluation_period
  metric_name         = "BurstBalance"
  namespace           = "AWS/RDS"
  period              = var.rds_alarm_statistic_period
  statistic           = "Average"
  threshold           = var.rds_disk_burst_balance_low_threshold
  alarm_description   = "Average database storage burst balance is too low, a negative performance impact is imminent."
  alarm_actions       = [aws_sns_topic.civiform_alert_topic.arn]

  dimensions = {
    DBInstanceIdentifier = data.aws_db_instance.civiform.id
  }
}

// Memory Utilization
resource "aws_cloudwatch_metric_alarm" "memory_freeable_too_low" {
  count               = var.rds_create_low_memory_alarm ? 1 : 0
  alarm_name          = "rds-${data.aws_db_instance.civiform.id}-lowFreeableMemory"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = var.rds_alarm_evaluation_period
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  period              = var.rds_alarm_statistic_period
  statistic           = "Average"
  threshold           = var.rds_low_memory_threshold
  alarm_description   = "Average database freeable memory is too low, performance may be negatively impacted."
  alarm_actions       = [aws_sns_topic.civiform_alert_topic.arn]

  dimensions = {
    DBInstanceIdentifier = data.aws_db_instance.civiform.id
  }
}

resource "aws_cloudwatch_metric_alarm" "memory_swap_usage_too_high" {
  count               = var.rds_create_swap_alarm ? 1 : 0
  alarm_name          = "rds-${data.aws_db_instance.civiform.id}-highSwapUsage"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.rds_alarm_evaluation_period
  metric_name         = "SwapUsage"
  namespace           = "AWS/RDS"
  period              = var.rds_alarm_statistic_period
  statistic           = "Average"
  threshold           = var.rds_high_swap_usage_threshold
  alarm_description   = "Average database swap usage is too high, performance may be negatively impacted."
  alarm_actions       = [aws_sns_topic.civiform_alert_topic.arn]

  dimensions = {
    DBInstanceIdentifier = data.aws_db_instance.civiform.id
  }
}

// Connection Count
resource "aws_cloudwatch_metric_alarm" "connection_count_anomalous" {
  count               = var.rds_create_anomaly_alarm ? 1 : 0
  alarm_name          = "rds-${data.aws_db_instance.civiform.id}-anomalousConnectionCount"
  comparison_operator = "GreaterThanUpperThreshold"
  evaluation_periods  = var.rds_alarm_evaluation_period
  threshold_metric_id = "e1"
  alarm_description   = "Anomalous database connection count detected. Check the monitoring graphs and logs for any suspicious activity."
  alarm_actions       = [aws_sns_topic.civiform_alert_topic.arn]

  metric_query {
    id          = "e1"
    expression  = "ANOMALY_DETECTION_BAND(m1, ${var.rds_anomaly_bandwidth})"
    label       = "DatabaseConnections (Expected)"
    return_data = "true"
  }

  metric_query {
    id          = "m1"
    return_data = "true"
    metric {
      metric_name = "DatabaseConnections"
      namespace   = "AWS/RDS"
      period      = var.rds_anomaly_period
      stat        = "Average"
      unit        = "Count"

      dimensions = {
        DBInstanceIdentifier = data.aws_db_instance.civiform.id
      }
    }
  }
}

// Early Warning System for Transaction ID Wraparound for postgres
resource "aws_cloudwatch_metric_alarm" "maximum_used_transaction_ids_too_high" {
  count               = var.rds_create_transaction_id_wraparound_alarm ? 1 : 0
  alarm_name          = "rds-${data.aws_db_instance.civiform.id}-maximumUsedTransactionIDs"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.rds_alarm_evaluation_period
  metric_name         = "MaximumUsedTransactionIDs"
  namespace           = "AWS/RDS"
  period              = var.rds_alarm_statistic_period
  statistic           = "Average"
  threshold           = var.rds_max_used_transaction_ids_high_threshold
  alarm_description   = "Nearing a possible critical transaction ID wraparound. More info [here](https://aws.amazon.com/blogs/database/implement-an-early-warning-system-for-transaction-id-wraparound-in-amazon-rds-for-postgresql/)"
  alarm_actions       = [aws_sns_topic.civiform_alert_topic.arn]
}

locals {
  ecs_cluster_name = module.ecs_cluster.aws_ecs_cluster_cluster_name
  ecs_service_name = "${var.app_prefix} Civiform Fargate Service"
}

#------------------------------------------------------------------------------
# AWS Auto Scaling - CloudWatch Alarm CPU High
#------------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "cpu_high_email" {
  alarm_name          = "${local.name_prefix}-cpu-high-email"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.ecs_max_cpu_evaluation_period
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = var.ecs_max_cpu_period
  statistic           = "Maximum"
  threshold           = var.ecs_max_cpu_threshold
  dimensions = {
    ClusterName = local.ecs_cluster_name
    ServiceName = local.ecs_service_name
  }
  alarm_actions = [aws_sns_topic.civiform_alert_topic.arn]

  tags = local.tags
}

#------------------------------------------------------------------------------
# AWS Auto Scaling - CloudWatch Alarm CPU Low
#------------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "cpu_low_email" {
  alarm_name          = "${local.name_prefix}-cpu-low-email"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = var.ecs_min_cpu_evaluation_period
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = var.ecs_min_cpu_period
  statistic           = "Average"
  threshold           = var.ecs_min_cpu_threshold
  dimensions = {
    ClusterName = local.ecs_cluster_name
    ServiceName = local.ecs_service_name
  }
  alarm_actions = [aws_sns_topic.civiform_alert_topic.arn]

  tags = local.tags
}


resource "aws_sns_topic" "civiform_alert_topic" {
  name = "civiform-alert-topic"
}

resource "aws_sns_topic_subscription" "civiform_alert_subscription" {
  topic_arn = aws_sns_topic.civiform_alert_topic.arn
  protocol  = "email"
  endpoint  = "daniellekatz@google.com"
}