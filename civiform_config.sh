#! /usr/bin/env bash

# CiviForm deployment configuration file.

#################################################
# Global variables for all CiviForm deployments
#################################################

# REQUIRED
# A supported CiviForm cloud provider, lower case.
export CIVIFORM_CLOUD_PROVIDER="aws"

# REQUIRED
# One of prod, staging, or dev.
export CIVIFORM_MODE="staging"

# REQUIRED
# The template directory for this deployment.
export TERRAFORM_TEMPLATE_DIR="cloud/aws/templates/aws_oidc"

# REQUIRED
# The short name for the civic entity. Ex. "Rochester"
export CIVIC_ENTITY_SHORT_NAME="AWS Civiform"

# REQUIRED
# The full name for the civic entity. Ex. "City of Rochester"
export CIVIC_ENTITY_FULL_NAME="Staging AWS Civiform"

# REQUIRED
# The email address to contact for support with using Civiform. Ex. "Civiform@CityOfRochester.gov
export CIVIC_ENTITY_SUPPORT_EMAIL_ADDRESS="civiform-azure-staging-email@googlegroups.com"

# REQUIRED
# A link to an image of the civic entity logo that includes the entity name, to be used in the header for the "Get Benefits" page
export CIVIC_ENTITY_LOGO_WITH_NAME_URL="https://raw.githubusercontent.com/civiform/staging-aws-deploy/main/logos/civiform-staging-long.png"

# REQUIRED
# A link to an image of the civic entity logo, to be used on the login page
export CIVIC_ENTITY_SMALL_LOGO_URL="https://raw.githubusercontent.com/civiform/staging-aws-deploy/main/logos/civiform-staging.png"

# REQUIRED
# The authentication protocl used for applicant and trusted intermediary accounts.
export CIVIFORM_APPLICANT_AUTH_PROTOCOL="oidc"

# REQUIRED
# Can only consist of lowercase letters and numbers, and must be between 3 and 24
# characters long.
export APPLICATION_NAME="CiviformAWS"

# REQUIRED
# The email address to use for the "from" field in emails sent from CiviForm.
export SENDER_EMAIL_ADDRESS="civiform-azure-staging-email@googlegroups.com"

# REQUIRED
# The email address that receives a notifications email each time an applicant
# submits an application to a program in the staging environments, instead of
# sending it to the program administrator's email, as would happen in prod.
export STAGING_PROGRAM_ADMIN_NOTIFICATION_MAILING_LIST="civiform-azure-staging-email@googlegroups.com"

# REQUIRED
# The email address that receives a notifications email each time an applicant
# submits an application to a program in the staging environments, instead of
# sending it to the trusted intermediary's email, as would happen in prod.
export STAGING_TI_NOTIFICATION_MAILING_LIST="civiform-azure-staging-email@googlegroups.com"

# REQUIRED
# The email address that receives a notifications email each time an applicant
# submits an application to a program in the staging environments, instead of
# sending it to the applicant's email, as would happen in prod.
export STAGING_APPLICANT_NOTIFICATION_MAILING_LIST="civiform-azure-staging-email@googlegroups.com"

# REQUIRED
# The custom domain name for this CiviForm deployment, not including the
# protocol. E.g. "civiform.seattle.gov"
export CUSTOM_HOSTNAME="staging-aws.civiform.dev"

# OPTIONAL
# The time zone to be used when rendering any times within the CiviForm
# UI. A list of valid time zone identifiers can be found at:
# https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
export CIVIFORM_TIME_ZONE_ID="America/Los_Angeles"
