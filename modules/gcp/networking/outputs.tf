output "vpc_id" {
  description = "Self-link of the VPC network"
  value       = google_compute_network.main.id
}

output "vpc_name" {
  description = "Name of the VPC network"
  value       = google_compute_network.main.name
}

output "subnet_id" {
  description = "Self-link of the primary subnet"
  value       = google_compute_subnetwork.main.id
}

output "subnet_name" {
  description = "Name of the primary subnet"
  value       = google_compute_subnetwork.main.name
}

output "router_name" {
  description = "Name of the Cloud Router"
  value       = google_compute_router.main.name
}

output "web_firewall_tag" {
  description = "Network tag to apply to web-tier instances"
  value       = "web-${var.environment}"
}

output "iap_ssh_tag" {
  description = "Network tag to apply to instances that need SSH via IAP"
  value       = "iap-ssh-${var.environment}"
}
