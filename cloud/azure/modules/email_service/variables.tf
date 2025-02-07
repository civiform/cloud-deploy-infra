variable "sender_email_address" {
  type        = string
  description = "Email address that emails will be sent from"
}

variable "create_aws_email_service" {
  type        = bool
  description = "Whether aws email service should be created"
}