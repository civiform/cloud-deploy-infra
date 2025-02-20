variable "civiform_server_environment_variables" {
  type        = map(string)
  description = "CiviForm server environment variables set in civiform_config.sh that are passed directly to the container environment."
  default     = {}
}

variable "azure_resource_group" {
  type        = string
  description = "Name of the resource group where key vault is already created."
}

variable "azure_skip_provider_registration" {
  type        = bool
  description = "Whether to skip provider registrations on azure, useful when using a principal with limited permissions."
  default     = false
}

variable "azure_subscription" {
  type        = string
  description = "The azure subscription id to deploy onto."
  default     = ""
}

variable "civiform_time_zone_id" {
  type        = string
  description = "Time zone for Civiform server to use when displaying dates."
  default     = "America/Los_Angeles"
}

variable "civic_entity_small_logo_url" {
  type        = string
  description = "Logo with name used on the applicant-facing program index page"
  default     = ""
}

variable "favicon_url" {
  type        = string
  description = "Browser Favicon (16x16 or 32x32 pixels, .ico, .png, or .gif) used on all pages"
  default     = "https://civiform.us/favicon.png"
}

variable "postgres_admin_login" {
  type        = string
  description = "Postgres admin login"
  default     = "psqladmin"
}

variable "image_tag" {
  type        = string
  description = "Tag for docker image to deploy"
}

variable "application_name" {
  type        = string
  description = "Azure Web App Name"
}

variable "key_vault_name" {
  type        = string
  description = "Name of key vault where secrets are stored."
}

variable "aws_region" {
  type        = string
  description = "Region where the AWS servers will live. Azure support for AWS isn't supported (#9258), so this is unused"
  default     = "us-east-1"
}

variable "email_provider" {
  type        = string
  description = "The provider to use for sending emails"
  default     = "graph-api"
}

variable "sender_email_address" {
  type        = string
  description = "Email address that emails will be sent from"
}

variable "custom_hostname" {
  type        = string
  description = "custom hostname for the app to map the dns (used also for CORS)"
  default     = "staging-azure.civiform.dev"
}

variable "adfs_admin_group" {
  type        = string
  description = "Active Directory Federation Service group name"
  default     = ""
}

variable "staging_program_admin_notification_mailing_list" {
  type        = string
  description = "Admin notification mailing list for staging"
}

variable "staging_ti_notification_mailing_list" {
  type        = string
  description = "intermediary notification mailing list for staging"
}

variable "staging_applicant_notification_mailing_list" {
  type        = string
  description = "Applicant notification mailing list for staging"
}

variable "civiform_applicant_auth_protocol" {
  type        = string
  description = "auth protocol to use for applicant auth. supported values are oidc and saml"
}

variable "login_radius_api_key" {
  type        = string
  description = "Login Radius API Key"
  default     = null
}

variable "login_radius_metadata_uri" {
  type        = string
  description = "LoginRadius endpoint for fetching IdP metadata"
  default     = null
}

variable "login_radius_saml_app_name" {
  type        = string
  description = "The App Name for the LoginRadius SAML integration"
  default     = null
}

variable "saml_keystore_filename" {
  type        = string
  description = "The name of the keystore file to use for SAML auth"
  default     = "civiformSamlKeystore.jks"
}

variable "saml_keystore_account_name" {
  type        = string
  description = "The storage account where the SAML keystore file is hosted"
}


variable "saml_keystore_container_name" {
  type        = string
  description = "The name of the keystore file"
  default     = "saml-keystore"
}

variable "civiform_api_keys_ban_global_subnet" {
  type        = bool
  description = "Whether to allow 0.0.0.0/0 subnet for API key access."
  default     = true
}

variable "civiform_server_metrics_enabled" {
  type        = bool
  description = "Whether to enable exporting server metrics on the /metrics route."
  default     = false
}
