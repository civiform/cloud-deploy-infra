terraform {
  required_providers {
    # aws = {
    #   source  = "hashicorp/aws"
    #   version = "5.78.0"
    # }
    azurerm = {
      source  = "azurerm"
      version = "4.11.0"
    }
    random = {}
  }
  backend "azurerm" {}
  required_version = ">= 0.14.9"
}

module "app" {
  source = "../../modules/app"

  resource_group_name = var.azure_resource_group

  postgres_admin_login = var.postgres_admin_login

  image_tag = var.image_tag

  civiform_applicant_auth_protocol = var.civiform_applicant_auth_protocol
  key_vault_name                   = var.key_vault_name

  application_name = var.application_name

  sender_email_address = var.sender_email_address

  staging_program_admin_notification_mailing_list = var.staging_program_admin_notification_mailing_list
  staging_ti_notification_mailing_list            = var.staging_ti_notification_mailing_list
  staging_applicant_notification_mailing_list     = var.staging_applicant_notification_mailing_list

  saml_keystore_filename = module.saml_keystore.filename

  # These two values need to match for PKCS12 keys
  saml_keystore_password    = module.saml_keystore.keystore_password
  saml_private_key_password = module.saml_keystore.keystore_password

  saml_keystore_storage_access_key     = module.saml_keystore.storage_access_key
  saml_keystore_storage_account_name   = module.saml_keystore.storage_account_name
  saml_keystore_storage_container_name = module.saml_keystore.storage_container_name
}

module "custom_hostname" {
  for_each                      = var.custom_hostname != "" ? toset([var.custom_hostname]) : toset([])
  source                        = "../../modules/custom_hostname"
  custom_hostname               = var.custom_hostname
  app_service_name              = module.app.app_service_name
  resource_group_name           = module.app.resource_group_name
  custom_domain_verification_id = module.app.custom_domain_verification_id
}

module "saml_keystore" {
  source                       = "../../modules/saml_keystore"
  key_vault_name               = var.key_vault_name
  saml_keystore_filename       = var.saml_keystore_filename
  saml_keystore_container_name = var.saml_keystore_container_name
  saml_keystore_account_name   = var.saml_keystore_account_name
  resource_group_name          = var.azure_resource_group
}



module "email_service" {
  # Only create the aws_ses module if that is the email_provider
  for_each = toset([
    var.sender_email_address,
    var.staging_applicant_notification_mailing_list,
    var.staging_ti_notification_mailing_list,
    var.staging_program_admin_notification_mailing_list
  ])
  source                   = "../../modules/email_service"
  create_aws_email_service = var.email_provider == "aws-ses" ? true : false
  sender_email_address     = each.key
}
