// File containing the necessary data sources if enable_managed_vpc=false

data "aws_vpc" "external" {
  count = local.enable_managed_vpc ? 0 : 1
  id    = var.external_vpc.id
}

data "aws_db_subnet_group" "external" {
  count = local.enable_managed_vpc ? 0 : 1
  name  = var.external_vpc.database_subnet_group_name
}

data "aws_subnet" "external_private" {
  count = local.enable_managed_vpc ? 0 : 1
  id    = var.external_vpc.private_subnet_id
}

data "aws_subnet" "external_public" {
  count = local.enable_managed_vpc ? 0 : 1
  id    = var.external_vpc.public_subnet_id
}
