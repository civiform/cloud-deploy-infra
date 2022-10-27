variable "app_prefix" {
  type        = string
  description = "A prefix to add to values so we can have multiple deploys in the same aws account"
}
variable "aws_region" {
  type        = string
  description = "Region where the AWS servers will live"
}
variable "vpc_id" {
  type        = string
  description = "ID of the VPC to depoy pgadmin in"
}
variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs to deploy pgadmin tasks in"
}

variable "lb_arn" {
  type        = string
  description = "ARN of the load balancer to hook pgadmin tasks up to"
}
variable "lb_ssl_cert_arn" {
  type        = string
  description = "ARN of the SSL certificate used by the load balancer"
}
variable "lb_access_sg_id" {
  type        = string
  description = "ID of the security group the load balancer runs in"
}
variable "ecs_cluster_arn" {
  type        = string
  description = "ARN of the ESC cluster the pgadmin service will be deployed in"
}

variable "db_sg_id" {
  type        = string
  description = "ID of the security group the database runs in"
}
variable "db_address" {
  type        = string
  description = "DNS name of the database"
}
variable "db_port" {
  type        = string
  description = "Port number the database is running on"
}
variable "db_username_secret_arn" {
  type        = string
  description = "ARN of the database username secret version"
}

variable "secrets_kms_key_arn" {
  type        = string
  description = "ARN of the KMS key used to encrypt secrets"
}
variable "secrets_recovery_window_in_days" {
  type        = string
  description = "Recovery window for secrets"
}
