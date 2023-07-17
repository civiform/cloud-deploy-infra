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
  alarm_actions       = var.rds_alarm_triggered_actions
  ok_actions          = var.rds_alarm_cleared_actions

  dimensions = {
    DBInstanceIdentifier = data.aws_db_instance.civiform.id
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu_credit_balance_too_low" {
  count               = var.rds_create_low_cpu_credit_alarm ? length(regexall("(t2|t3)", var.postgres_instance_class)) > 0 ? 1 : 0 : 0
  alarm_name          = "rds-${data.aws_db_instance.civiform.id}-lowCPUCreditBalance"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = var.rds_alarm_evaluation_period
  metric_name         = "CPUCreditBalance"
  namespace           = "AWS/RDS"
  period              = var.rds_alarm_statistic_period
  statistic           = "Average"
  threshold           = var.rds_low_cpu_credit_balance_threshold
  alarm_description   = "Average database CPU credit balance is too low, a negative performance impact is imminent."

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

  dimensions = {
    DBInstanceIdentifier = data.aws_db_instance.civiform.id
  }
}
#
#// Connection Count
#resource "aws_cloudwatch_metric_alarm" "connection_count_anomalous" {
#  count               = var.rds_create_anomaly_alarm ? 1 : 0
#  alarm_name          = "rds-${data.aws_db_instance.civiform.id}-anomalousConnectionCount"
#  comparison_operator = "GreaterThanUpperThreshold"
#  evaluation_periods  = var.rds_alarm_evaluation_period
#  threshold_metric_id = "e1"
#  alarm_description   = "Anomalous database connection count detected. Something unusual is happening."
#
#  metric_query {
#    id          = "e1"
#    expression  = "ANOMALY_DETECTION_BAND(m1, ${var.anomaly_band_width})"
#    label       = "DatabaseConnections (Expected)"
#    return_data = "true"
#  }
#
#  metric_query {
#    id          = "m1"
#    return_data = "true"
#    metric {
#      metric_name = "DatabaseConnections"
#      namespace   = "AWS/RDS"
#      period      = var.anomaly_period
#      stat        = "Average"
#      unit        = "Count"
#
#      dimensions = {
#        DBInstanceIdentifier = data.aws_db_instance.civiform.id
#      }
#    }
#  }
#}
#
#// Early Warning System for Transaction ID Wraparound for postgres
#// more info - https://aws.amazon.com/blogs/database/implement-an-early-warning-system-for-transaction-id-wraparound-in-amazon-rds-for-postgresql/
#resource "aws_cloudwatch_metric_alarm" "maximum_used_transaction_ids_too_high" {
#  count               = contains(["aurora-postgresql", "postgres"], var.engine) ? 1 : 0
#  alarm_name          = "rds-${data.aws_db_instance.civiform.id}-maximumUsedTransactionIDs"
#  comparison_operator = "GreaterThanThreshold"
#  evaluation_periods  = var.rds_alarm_evaluation_period
#  metric_name         = "MaximumUsedTransactionIDs"
#  namespace           = "AWS/RDS"
#  period              = var.rds_alarm_statistic_period
#  statistic           = "Average"
#  threshold           = var.rds_max_used_transaction_ids_high_threshold
#  alarm_description   = "Nearing a possible critical transaction ID wraparound."
#}