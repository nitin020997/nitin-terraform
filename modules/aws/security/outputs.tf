output "web_sg_id" {
  description = "Security group ID for web tier"
  value       = aws_security_group.web.id
}

output "app_sg_id" {
  description = "Security group ID for app tier"
  value       = aws_security_group.app.id
}

output "database_sg_id" {
  description = "Security group ID for database tier"
  value       = aws_security_group.database.id
}

output "bastion_sg_id" {
  description = "Security group ID for bastion host"
  value       = aws_security_group.bastion.id
}

output "ec2_instance_profile_name" {
  description = "IAM instance profile name for EC2 instances"
  value       = aws_iam_instance_profile.ec2.name
}

output "ec2_role_arn" {
  description = "IAM role ARN for EC2 instances"
  value       = aws_iam_role.ec2_instance.arn
}

output "kms_key_id" {
  description = "KMS key ID for encryption (null if enable_kms is false)"
  value       = var.enable_kms ? aws_kms_key.main[0].key_id : null
}

output "kms_key_arn" {
  description = "KMS key ARN for encryption (null if enable_kms is false)"
  value       = var.enable_kms ? aws_kms_key.main[0].arn : null
}
