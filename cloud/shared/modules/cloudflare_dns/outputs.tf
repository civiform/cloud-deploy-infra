output "record_id" {
  value       = cloudflare_dns_record.cname.id
  description = "ID of the created Cloudflare DNS record"
}

output "record_name" {
  value       = cloudflare_dns_record.cname.name
  description = "Name of the created Cloudflare DNS record"
}
