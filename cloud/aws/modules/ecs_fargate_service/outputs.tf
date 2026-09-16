output "https_listener_arn" {
  description = "The ARN of the HTTPS listener for the loadbalancer. Null when create_load_balancer is false."
  value       = one(aws_lb_listener.lb_https_listeners[*].arn)
}
output "aws_lb_civiform_lb_arn" {
  description = "The ARN of the load balancer (matches id). Null when create_load_balancer is false."
  value       = one(aws_lb.civiform_lb[*].arn)
}

output "aws_security_group_lb_access_sg_id" {
  description = "The ID of the LB access security group. Null when create_load_balancer is false."
  value       = one(aws_security_group.lb_access_sg[*].id)
}

output "aws_security_group_ecs_tasks_access_sg_id" {
  description = "The ID of the ECS tasks access security group"
  value       = aws_security_group.ecs_tasks_sg.id
}

output "aws_ecs_service_name" {
  description = "The name of the AWS ECS service"
  value       = aws_ecs_service.service.name
}

output "lb_https_target_group_arn" {
  description = "ARN of the target group for the service. Callers that manage their own load balancer attach this to a listener rule."
  value       = aws_lb_target_group.lb_https_tgs.arn
}
