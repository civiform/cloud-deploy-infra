resource "aws_ses_email_identity" "email" {
  count = var.create_domain_verified_identity ? 0 : 1
  email = var.sender_email_address
}

resource "aws_ses_domain_identity" "domain" {
  count = var.create_domain_verified_identity ? 1 : 0
  domain = split("@", var.sender_email_address)[1]
}

output "identity_arn" {
  value = var.create_domain_verified_identity ? aws_ses_domain_identity.domain[0].arn : aws_ses_email_identity.email[0].arn
}
