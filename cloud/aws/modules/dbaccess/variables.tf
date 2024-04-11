variable "app_prefix" {
  type        = string
  description = "A prefix to add to values so we can have multiple deploys in the same aws account"
}
variable "aws_region" {
  type        = string
  description = "Region where the AWS servers will live"
}
variable "public_key" {
  type        = string
  description = "Path to the public key to use for SSH access"
}
variable "vpc_id" {
  type        = string
  description = "ID of the VPC to depoy pgadmin in"
}
variable "cidr_allowlist" {
  type        = list(string)
  description = "List of cidr block notations to allow traffic to pgadmin"

  validation {
    condition     = length(var.cidr_allowlist) > 0
    error_message = "Allowlist must not be empty"
  }
  validation {
    # Regexp lifted from https://www.regextester.com/93987, with:
    # - Removed optional subnet mask to match AWS provider validation.
    # - `\`s escaped.
    condition     = can([for c in var.cidr_allowlist : regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}(\\/([0-9]|[1-2][0-9]|3[0-2]))$", c)])
    error_message = "Each IPv4 cidr block must be valid notation"
  }
}
variable "public_subnet" {
  type        = string
  description = "ID of the public subnet to deploy the dbaccess instance in"
}
variable "host_ami" {
  type        = string
  description = "AMI ID to use for the dbaccess instance"
  default     = "ami-080e1f13689e07408"
}
variable "host_type" {
  type        = string
  description = "Instance type to use for the dbaccess instance"
  default     = "t2.micro"
}
variable "db_sg_id" {
  type        = string
  description = "ID of the security group the database runs in"
}
