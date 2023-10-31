output "https_listener_arn" {
  description = "The ARN of the HTTPS listener for the loadbalancer"
  value       = aws_lb_listener.lb_https_listeners.arn
}
output "aws_lb_civiform_lb_arn" {
  description = "The ARN of the load balancer (matches id)."
  value       = aws_lb.civiform_lb.arn
}

output "aws_security_group_lb_access_sg_id" {
  description = "The ID of the security group"
  value       = aws_security_group.lb_access_sg.id
}

output "aws_ecs_service_name" {
  description = "The service name of the aws ecs service."
  value       = aws_ecs_service.service.name
}
