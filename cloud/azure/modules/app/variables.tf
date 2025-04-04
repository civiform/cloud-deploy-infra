variable "civiform_server_environment_variables" {
  type        = map(string)
  description = "CiviForm server environment variables set in civiform_config.sh that are passed directly to the container environment."
  default     = {}
}

variable "application_name" {
  type        = string
  description = "Azure Web App Name"
}

variable "aws_region" {
  type        = string
  description = "Region for the aws account. Azure support for AWS isn't supported (#9258), so this is unused"
  default     = "us-east-1"
}

variable "civiform_image_repo" {
  type        = string
  description = "Dockerhub repository with Civiform images"
  default     = "civiform/civiform"
}

variable "image_tag" {
  type        = string
  description = "Tag for container image"
  default     = "latest"
}

variable "location_name" {
  type        = string
  description = "Name of the location for the resource group"
  default     = "eastus"
}

variable "vnet_address_space" {
  type        = list(string)
  description = "List of vnet address_spaces"
  default = [
    "10.0.0.0/16"
  ]
}

variable "subnet_address_prefixes" {
  type        = list(string)
  description = "List of the apps subnet address prefixes (must be distinct from the postgress subnet)"
  default = [
    "10.0.2.0/24"
  ]
}

variable "bastion_address_prefixes" {
  type        = list(string)
  description = "Prefixes for the bastion instance (must be distinct from other subnets)"
  default = [
    "10.0.6.0/24"
  ]
}

variable "app_sku" {
  type        = string
  description = "SKU tier information"
  default     = "S2"
}

variable "resource_group_name" {
  type    = string
  default = "civiform-resourcegroup"
}

variable "postgres_admin_login" {
  type        = string
  description = "Postgres admin login"
  default     = "psqladmin"
}

variable "postgres_sku_name" {
  type        = string
  description = "The sku name for postgres server"
  default     = "GP_Standard_D2s_v3"
}
variable "postgres_storage_mb" {
  type        = number
  description = "The mb of storage for postgres instance"
  default     = 32768
}

variable "postgres_backup_retention_days" {
  type        = number
  description = "Number of days to retain postgres backup"
  default     = 7
}

variable "postgres_subnet_address_prefixes" {
  type        = list(string)
  description = "A list of the subnet address prefixes for postgres (must be distinct from the app's subnet addresses)"
  default = [
    "10.0.4.0/24"
  ]
}

variable "log_sku" {
  type        = string
  description = "The SKU for the sever logs"
  default     = "PerGB2018"
}

variable "log_retention" {
  type        = number
  description = "The number of days the logs will be retained for"
  default     = 30
}

variable "sender_email_address" {
  type        = string
  description = "Email address of who is sending the email, passed to the app"
}


variable "key_vault_name" {
  type        = string
  description = "Name of key vault where secrets are stored."
}

variable "civiform_applicant_auth_protocol" {
  type        = string
  description = "auth protocol to use for applicant auth. supported values are oidc and saml"
}

variable "saml_keystore_filename" {
  description = "Name of Java Keystore file stored in Azure blob storage"
  default     = null
}

variable "saml_keystore_password" {
  description = "Password for Java Keystore file"
  default     = null
}

variable "saml_private_key_password" {
  description = "Password for Java Keystore private key"
  default     = null
}

variable "saml_keystore_storage_account_name" {
  description = "Name of storage account where Java Keystore is stored"
  default     = null
}

variable "saml_keystore_storage_container_name" {
  description = "Name of storage container where Java Keystore is stored"
  default     = null
}

variable "saml_keystore_storage_access_key" {
  description = "Key needed to access keystore file"
  default     = null
}

variable "staging_program_admin_notification_mailing_list" {
  type        = string
  description = "Admin notification mailing list for staging"
  default     = ""
}

variable "staging_ti_notification_mailing_list" {
  type        = string
  description = "intermediary notification mailing list for staging"
  default     = ""
}

variable "staging_applicant_notification_mailing_list" {
  type        = string
  description = "Applicant notification mailing list for staging"
  default     = ""
}


