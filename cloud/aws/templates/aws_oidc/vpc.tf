# Souce: https://learn.hashicorp.com/tutorials/terraform/aws-rds?in=terraform/aws

data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.1"

  name             = "${var.app_prefix}-${var.vpc_name}"
  cidr             = var.vpc_cidr
  azs              = data.aws_availability_zones.available.names
  private_subnets  = var.private_subnets
  public_subnets   = var.public_subnets
  database_subnets = var.database_subnets

  // Enable public internet access
  enable_nat_gateway = true
  single_nat_gateway = true
  enable_vpn_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  map_public_ip_on_launch = true

  # TODO - make sure the DB is not accessable from the internet
  create_database_subnet_route_table     = true
  create_database_subnet_group           = true
  create_database_internet_gateway_route = false

  # VPC Flow Logs (Cloudwatch log group and IAM role will be created)
  enable_flow_log                      = true
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role  = true
  flow_log_max_aggregation_interval    = 60

  tags = {
    Module = "Civiform VPC"
  }
  public_subnet_tags = {
    Name = "${var.app_prefix} Civiform Public Subnet"
    Type = "Civiform Public Subnet"
  }
  vpc_tags = {
    Name = "${var.app_prefix} Civiform VPC"
    Type = "Civiform VPC"
  }
  private_route_table_tags = {
    Name = "${var.app_prefix} Civiform VPC Private Route"
    Type = "Civiform VPC Private Route"
  }
  private_subnet_tags = {
    Name = "${var.app_prefix} Civiform VPC Private Subnet"
    Type = "Civiform VPC Private Subnet"
  }
  public_acl_tags = {
    Name = "${var.app_prefix} Civiform VPC Public ACL"
    Type = "Civiform VPC Public ACL"
  }
  public_route_table_tags = {
    Name = "${var.app_prefix} Civiform VPC Public Route"
    Type = "Civiform VPC Public Route"
  }
  vpc_flow_log_tags = {
    Name = "${var.app_prefix} Civiform VPC Flow Logs"
    Type = "Civiform VPC Flow Logs"
  }
  vpn_gateway_tags = {
    Name = "${var.app_prefix} Civiform VPC Gateway"
    Type = "Civiform VPC Gateway"
  }

}
