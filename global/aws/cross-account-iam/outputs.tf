output "cicd_role_arn" {
  description = "ARN of the GitHub Actions CI/CD role — use in workflow's role-to-assume"
  value       = aws_iam_role.cicd.arn
}

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider"
  value       = aws_iam_openid_connect_provider.github.arn
}
