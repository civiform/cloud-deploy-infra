variable "region" {
  type        = string
  description = "Default region for the db"
}

variable "tier_type" {
  type        = string
  description = "tier type to use for the db instance"
}

variable "service_account" {
  type        = string
  description = "service account being used by terraform"
}

variable "postgres_version" {
  type = string
  description = "version of postgres to use"
  default = "POSTGRES_16"
}
