resource "cloudflare_dns_record" "cname" {
  zone_id = var.cloudflare_zone_id
  name    = var.record_name
  content = var.target_dns_name
  type    = "CNAME"
  ttl     = var.ttl
  proxied = var.proxied
  comment = "Managed by CiviForm deployment for ${var.app_prefix}"
}
