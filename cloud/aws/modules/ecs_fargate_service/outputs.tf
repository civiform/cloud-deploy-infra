# NLB Outputs
output "nlb_arn" {
  description = "The ARN of the Network Load Balancer (NLB)"
  value       = aws_lb.nlb.arn
}

output "nlb_dns_name" {
  description = "The DNS name of the Network Load Balancer (NLB)"
  value       = aws_lb.nlb.dns_name
}

output "nlb_listener_arn" {
  description = "The ARN of the TCP listener on the NLB"
  value       = aws_lb_listener.nlb_listener.arn
}

# ALB Outputs
output "alb_arn" {
  description = "The ARN of the Application Load Balancer (ALB)"
  value       = aws_lb.civiform_lb.arn
}

output "alb_target_group_arn" {
  description = "The ARN of the ALB target group"
  value       = aws_lb_target_group.lb_https_tgs.arn
}

# Security Group Output
output "aws_security_group_lb_access_sg_id" {
  description = "The ID of the ALB security group"  # Clarified for ALB
  value       = aws_security_group.lb_access_sg.id
}

# ECS Service Output
output "aws_ecs_service_name" {
  description = "The name of the AWS ECS service"
  value       = aws_ecs_service.service.name
}
