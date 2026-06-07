output "load_balancer_ip" {
  description = "Global load balancer IP address"
  value       = google_compute_global_forwarding_rule.app.ip_address
}

output "instance_group_url" {
  description = "Instance group self-link"
  value       = google_compute_region_instance_group_manager.app.instance_group
}

output "service_account_email" {
  description = "Service account email for app instances"
  value       = google_service_account.app.email
}
