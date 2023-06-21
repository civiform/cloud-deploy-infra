output "lb_https_listeners_arns" {
  description = "List of HTTPS Listeners ARNs"
  value       = [for listener in aws_lb_listener.lb_https_listeners : listener.arn]
}

output "aws_lb_lb_arn" {
  description = "The ARN of the load balancer (matches id)."
  value       = aws_lb.lb.arn
}

output "aws_security_group_lb_access_sg_id" {
  description = "The ID of the security group"
  value       = aws_security_group.lb_access_sg.id
}