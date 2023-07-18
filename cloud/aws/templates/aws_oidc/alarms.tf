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
