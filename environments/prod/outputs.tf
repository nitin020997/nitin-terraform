output "vpc_id" {
  value = module.networking.vpc_id
}

output "alb_dns_name" {
  value = module.compute.alb_dns_name
}

output "asg_name" {
  value = module.compute.asg_name
}

output "db_secret_arn" {
  description = "ARN of Secrets Manager secret containing DB credentials"
  value       = module.database.db_secret_arn
}
