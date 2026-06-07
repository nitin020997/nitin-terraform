output "load_balancer_ip" {
  description = "Public IP of the OCI Load Balancer"
  value       = oci_load_balancer_load_balancer.app.ip_address_details[0].ip_address
}

output "instance_pool_id" {
  description = "OCID of the Instance Pool"
  value       = oci_core_instance_pool.app.id
}

output "autoscaling_config_id" {
  description = "OCID of the autoscaling configuration"
  value       = oci_autoscaling_auto_scaling_configuration.app.id
}
