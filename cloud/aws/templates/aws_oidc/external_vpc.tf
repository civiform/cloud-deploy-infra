// File containing the necessary data sources if local.enable_managed_vpc=false.
//
// The "local.enable_managed_vpc" variable will be set to false if all of
// "external_vpc" variables are set.

data "aws_vpc" "external" {
  count = local.enable_managed_vpc ? 0 : 1
  id    = var.external_vpc_id
}

data "aws_db_subnet_group" "external" {
  count = local.enable_managed_vpc ? 0 : 1
  name  = var.external_vpc_database_subnet_group_name
}

data "aws_subnets" "external_private_subnets" {
  count = local.enable_managed_vpc ? 0 : 1
  filter {
    name   = "subnet-id"
    values = external_vpc_private_subnets
  }
}

data "aws_subnets" "external_public_subnets" {
  count = local.enable_managed_vpc ? 0 : 1
  filter {
    name   = "subnet-id"
    values = external_vpc_public_subnets
  }
}
