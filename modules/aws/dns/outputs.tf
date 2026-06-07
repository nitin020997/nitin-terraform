output "zone_id" {
  description = "Route53 hosted zone ID"
  value       = aws_route53_zone.main.zone_id
}

output "name_servers" {
  description = "Route53 name servers — update your domain registrar with these"
  value       = aws_route53_zone.main.name_servers
}

output "primary_health_check_id" {
  description = "Route53 health check ID for primary region"
  value       = aws_route53_health_check.primary.id
}

output "dr_health_check_id" {
  description = "Route53 health check ID for DR region"
  value       = aws_route53_health_check.dr.id
}

output "api_fqdn" {
  description = "Fully qualified domain name for the API endpoint"
  value       = aws_route53_record.primary.fqdn
}
