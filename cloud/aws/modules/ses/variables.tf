variable "sender_email_address" {
  type        = string
  description = "Email address that emails will be sent from"
}

variable "create_domain_verified_identity" {
  type        = bool
  description = "If a domain-verified identity should be created. If false, an email-verified identity is created."
  default     = false
}
