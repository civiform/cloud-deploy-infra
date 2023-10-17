// SNS topic to alert if an alarm gets triggered
resource "aws_sns_topic" "civiform_alert_topic" {
  count = var.civiform_alarm_email != "" ? 1 : 0
  name  = "${var.app_prefix}-civiform-alert-topic"
}

resource "aws_sns_topic_subscription" "civiform_alert_subscription" {
  count     = var.civiform_alarm_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.civiform_alert_topic[0].arn
  protocol  = "email"
  endpoint  = var.civiform_alarm_email
}

locals {
  civiform_alarm_actions = var.civiform_alarm_email != "" ? [aws_sns_topic.civiform_alert_topic[0].arn] : []
}

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
  alarm_actions       = local.civiform_alarm_actions

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
  alarm_actions       = local.civiform_alarm_actions

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
  alarm_actions       = local.civiform_alarm_actions

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
  alarm_actions       = local.civiform_alarm_actions

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
  alarm_actions       = local.civiform_alarm_actions

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
  alarm_actions       = local.civiform_alarm_actions

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
  alarm_actions       = local.civiform_alarm_actions

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
  alarm_actions       = local.civiform_alarm_actions

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
  alarm_actions       = local.civiform_alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "memory_utilization_too_high" {
  count               = var.ecs_create_high_memory_alarm ? 1 : 0
  alarm_name          = "ecs-${module.ecs_cluster.aws_ecs_cluster_cluster_name}-highMemoryUtilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.ecs_alarm_evaluation_period
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = var.ecs_alarm_statistic_period
  statistic           = "Average"
  threshold           = var.ecs_max_memory_utilization_threshold
  alarm_description   = "Average ECS service memory utilization is too high."
  alarm_actions       = local.civiform_alarm_actions

  dimensions = {
    ClusterName = module.ecs_cluster.aws_ecs_cluster_cluster_name
    ServiceName = "${module.ecs_cluster.aws_ecs_cluster_cluster_name}-service"
  }
}
