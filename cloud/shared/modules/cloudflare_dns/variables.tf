variable "aws_region" {
  type        = string
  description = "AWS region for Secrets Manager and backend"
  default     = "us-east-1"
}

variable "cloudflare_api_token_secret_id" {
  type        = string
  description = "AWS Secrets Manager secret ARN or name containing the Cloudflare API token"
  default     = null
}

variable "cloudflare_zone_id" {
  type        = string
  description = "Cloudflare Zone ID where the DNS record will be created"
  default     = null
}

variable "record_name" {
  type        = string
  description = "Name of the DNS record to create"
  default     = null
}

variable "target_dns_name" {
  type        = string
  description = "Target DNS name for the CNAME record (e.g. load balancer DNS name)"
  default     = null
}

variable "ttl" {
  type        = number
  description = "TTL for the DNS record in seconds (1 for automatic)"
  default     = 1
}

variable "proxied" {
  type        = bool
  description = "Whether the DNS record should be proxied through Cloudflare"
  default     = false
}

variable "app_prefix" {
  type        = string
  description = "Prefix for resources in this deployment"
  default     = "civiform"
}
