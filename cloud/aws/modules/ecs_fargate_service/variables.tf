#------------------------------------------------------------------------------
# Misc
#------------------------------------------------------------------------------
variable "app_prefix" {
  description = "App prefix for naming resources on AWS. For most resources, -civiform is added to this string."
}

#------------------------------------------------------------------------------
# AWS Networking
#------------------------------------------------------------------------------
variable "vpc_id" {
  description = "ID of the VPC"
}

#------------------------------------------------------------------------------
# AWS ECS SERVICE
#------------------------------------------------------------------------------
variable "ecs_cluster_arn" {
  description = "ARN of an ECS cluster"
}

variable "desired_count" {
  description = "(Optional) The number of instances of the task definition to place and keep running. Defaults to 0."
  type        = number
  default     = 1
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Resource tags"
}

variable "task_definition_arn" {
  description = "(Required) The full ARN of the task definition that you want to run in your service."
}

#------------------------------------------------------------------------------
# AWS ECS SERVICE network_configuration BLOCK
#------------------------------------------------------------------------------
variable "public_subnets" {
  description = "The public subnets associated with the task or service."
  type        = list(any)
}

variable "private_subnets" {
  description = "The private subnets associated with the task or service."
  type        = list(any)
}

#------------------------------------------------------------------------------
# AWS ECS SERVICE load_balancer BLOCK
#------------------------------------------------------------------------------
variable "container_name" {
  description = "Name of the running container"
}

#------------------------------------------------------------------------------
# AWS ECS SERVICE AUTOSCALING
#------------------------------------------------------------------------------
variable "ecs_cluster_name" {
  description = "(Optional) Name of the ECS cluster. Required only if autoscaling is enabled"
  type        = string
  default     = null
}

variable "max_cpu_threshold" {
  description = "Threshold for max CPU usage"
  default     = "85"
  type        = string
}
variable "min_cpu_threshold" {
  description = "Threshold for min CPU usage"
  default     = "10"
  type        = string
}

variable "max_cpu_evaluation_period" {
  description = "The number of periods over which data is compared to the specified threshold for max cpu metric alarm"
  default     = "3"
  type        = string
}
variable "min_cpu_evaluation_period" {
  description = "The number of periods over which data is compared to the specified threshold for min cpu metric alarm"
  default     = "3"
  type        = string
}

variable "max_cpu_period" {
  description = "The period in seconds over which the specified statistic is applied for max cpu metric alarm"
  default     = "60"
  type        = string
}
variable "min_cpu_period" {
  description = "The period in seconds over which the specified statistic is applied for min cpu metric alarm"
  default     = "60"
  type        = string
}

variable "scale_target_max_capacity" {
  description = "The max capacity of the scalable target"
  default     = 5
  type        = number
}

variable "scale_target_min_capacity" {
  description = "The min capacity of the scalable target"
  default     = 1
  type        = number
}

#------------------------------------------------------------------------------
# ACCESS CONTROL TO APPLICATION LOAD BALANCER
#------------------------------------------------------------------------------
variable "https_target_port" {
  description = "The target port the application is running on"
  default     = 9000
  type        = number
}

#------------------------------------------------------------------------------
# AWS LOAD BALANCER - Target Groups
#------------------------------------------------------------------------------
variable "ssl_policy" {
  description = "(Optional) The name of the SSL Policy for the listener. . Required if var.https_ports is set."
  type        = string
  default     = null
}

variable "default_certificate_arn" {
  description = "(Optional) The ARN of the default SSL server certificate. Required if var.https_ports is set."
  type        = string
  default     = null
}