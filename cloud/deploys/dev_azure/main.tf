terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.75.1"
    }
    azurerm = {
      source  = "azurerm"
      version = "3.0.2"
    }
    random = {}
  }
  required_version = ">= 0.14.9"
}

module "app" {
  source               = "../../azure/modules/app"
  resource_group_name  = var.resource_group_name
  postgres_admin_login = var.postgres_admin_login
  postgres_sku_name    = "GP_Gen5_2"

  image_tag = var.image_tag

  key_vault_name = var.key_vault_name

  application_name = var.application_name

  ses_sender_email = var.sender_email_address

  staging_program_admin_notification_mailing_list = var.staging_program_admin_notification_mailing_list
  staging_ti_notification_mailing_list            = var.staging_ti_notification_mailing_list
  staging_applicant_notification_mailing_list     = var.staging_applicant_notification_mailing_list

  civic_entity_short_name            = var.civic_entity_short_name
  civic_entity_full_name             = var.civic_entity_full_name
  civic_entity_support_email_address = var.civic_entity_support_email_address
  civic_entity_logo_with_name_url    = var.civic_entity_logo_with_name_url
  civic_entity_small_logo_url        = var.civic_entity_small_logo_url

  adfs_admin_group = var.adfs_admin_group

  civiform_applicant_idp           = "login-radius"
  civiform_applicant_auth_protocol = "saml"

  login_radius_api_key       = var.login_radius_api_key
  login_radius_metadata_uri  = var.login_radius_metadata_uri
  login_radius_saml_app_name = var.login_radius_saml_app_name
  saml_keystore_filename     = module.saml_keystore.filename

  # These two values need to match for PKCS12 keys
  saml_keystore_password    = module.saml_keystore.keystore_password
  saml_private_key_password = module.saml_keystore.keystore_password

  saml_keystore_storage_access_key     = module.saml_keystore.storage_access_key
  saml_keystore_storage_account_name   = module.saml_keystore.storage_account_name
  saml_keystore_storage_container_name = module.saml_keystore.storage_container_name

}

module "saml_keystore" {
  source                       = "../../azure/modules/saml_keystore"
  key_vault_name               = var.key_vault_name
  resource_group_name          = var.resource_group_name
  saml_keystore_filename       = var.saml_keystore_filename
  saml_keystore_container_name = var.saml_keystore_container_name
  saml_keystore_account_name   = var.saml_keystore_account_name
}

module "email_service" {
  source               = "../../aws/modules/ses"
  sender_email_address = var.sender_email_address
}

module "program_admin_email" {
  source               = "../../aws/modules/ses"
  sender_email_address = var.staging_program_admin_notification_mailing_list
}

module "ti_admin_email" {
  source               = "../../aws/modules/ses"
  sender_email_address = var.staging_ti_notification_mailing_list
}

module "applicant_email" {
  source               = "../../aws/modules/ses"
  sender_email_address = var.staging_applicant_notification_mailing_list
}
