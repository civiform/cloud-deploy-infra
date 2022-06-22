#! /usr/bin/env bash

# CiviForm deployment configuration file for AWS staging.

export APP_PREFIX="staging-aws"
export CIVIFORM_CLOUD_PROVIDER="aws"
export CIVIFORM_MODE="staging"
export TERRAFORM_TEMPLATE_DIR="cloud/aws/templates/aws_oidc"
export CIVIC_ENTITY_SHORT_NAME="AWS Civiform"
export CIVIC_ENTITY_FULL_NAME="Staging AWS Civiform"
export CIVIC_ENTITY_SUPPORT_EMAIL_ADDRESS="civiform-azure-staging-email@googlegroups.com"
export CIVIC_ENTITY_LOGO_WITH_NAME_URL="https://raw.githubusercontent.com/civiform/staging-aws-deploy/main/logos/civiform-staging-long.png"
export CIVIC_ENTITY_SMALL_LOGO_URL="https://raw.githubusercontent.com/civiform/staging-aws-deploy/main/logos/civiform-staging.png"
export CIVIFORM_APPLICANT_AUTH_PROTOCOL="oidc"
export APPLICATION_NAME="CiviformAWS"
export SENDER_EMAIL_ADDRESS="civiform-azure-staging-email@googlegroups.com"
export STAGING_PROGRAM_ADMIN_NOTIFICATION_MAILING_LIST="civiform-azure-staging-email@googlegroups.com"
export STAGING_TI_NOTIFICATION_MAILING_LIST="civiform-azure-staging-email@googlegroups.com"
export STAGING_APPLICANT_NOTIFICATION_MAILING_LIST="civiform-azure-staging-email@googlegroups.com"
export CUSTOM_HOSTNAME="staging-aws.civiform.dev"
export CIVIFORM_TIME_ZONE_ID="America/Los_Angeles"
