output "org_id" {
  description = "AWS Organization ID"
  value       = aws_organizations_organization.main.id
}

output "root_id" {
  description = "Organization root ID"
  value       = aws_organizations_organization.main.roots[0].id
}

output "dev_account_id" {
  description = "Dev workload account ID"
  value       = aws_organizations_account.dev.id
}

output "staging_account_id" {
  description = "Staging workload account ID"
  value       = aws_organizations_account.staging.id
}

output "prod_account_id" {
  description = "Prod workload account ID"
  value       = aws_organizations_account.prod.id
}

output "security_account_id" {
  description = "Security account ID"
  value       = aws_organizations_account.security.id
}

output "shared_services_account_id" {
  description = "Shared services account ID"
  value       = aws_organizations_account.shared_services.id
}
