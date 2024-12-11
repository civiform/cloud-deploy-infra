variable "region" {
  type        = string
  description = "Default region for bucket resources"
}

variable "application_name_postfix" {
  type        = string
  description = "Company name to be used postfix"
}

variable "service_account" {
  type        = string
  description = "service account being used by terraform"
}
