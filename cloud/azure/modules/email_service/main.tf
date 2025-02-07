module "email_service" {
  # Only create the aws_ses module if that is the email_provider
  source               = "../../../aws/modules/ses"
  count                = var.create_aws_email_service ? 1 : 0
  sender_email_address = var.sender_email_address
}

# output "email_arn" {
#   value = "not_implemented"
# }