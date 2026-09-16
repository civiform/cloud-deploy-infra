output "task_execution_role_arn" {
  description = "ARN of the ECS task execution role. Used as both the task role and the execution role, and referenced by the S3 bucket policies that grant the app access to its buckets."
  value       = aws_iam_role.civiform_ecs_task_execution_role.arn
}

output "task_execution_role_name" {
  description = "Name of the ECS task execution role, for attaching additional policies."
  value       = aws_iam_role.civiform_ecs_task_execution_role.name
}

output "civiform_only_task_definition_arn" {
  description = "ARN of the task definition running the CiviForm server alone."
  value       = aws_ecs_task_definition.civiform_only.arn
}

output "civiform_with_monitoring_task_definition_arn" {
  description = "ARN of the task definition running the CiviForm server alongside the metrics scraper."
  value       = aws_ecs_task_definition.civiform_with_monitoring.arn
}

output "server_container_name" {
  description = "Name of the CiviForm server container, which a load balancer target group attaches to."
  value       = local.server_container_name
}
