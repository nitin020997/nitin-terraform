output "global_cluster_id" {
  description = "Global cluster identifier"
  value       = aws_rds_global_cluster.main.id
}

output "primary_cluster_endpoint" {
  description = "Writer endpoint — use this for all database writes"
  value       = aws_rds_cluster.primary.endpoint
  sensitive   = true
}

output "primary_reader_endpoint" {
  description = "Reader endpoint in primary region — for read scaling"
  value       = aws_rds_cluster.primary.reader_endpoint
  sensitive   = true
}

output "secondary_reader_endpoint" {
  description = "Reader endpoint in DR region — becomes writer endpoint after failover"
  value       = aws_rds_cluster.secondary.reader_endpoint
  sensitive   = true
}
