variable "environment" {
  type = string
}

variable "primary_db_instance_id" {
  description = "RDS instance ID in the primary region to promote to global cluster primary"
  type        = string
}

variable "dr_subnet_group_name" {
  description = "DB subnet group name in the DR region"
  type        = string
}

variable "dr_security_group_id" {
  description = "Security group ID for RDS in the DR region"
  type        = string
}

variable "dr_kms_key_arn" {
  description = "KMS key ARN in the DR region for encryption"
  type        = string
  default     = null
}

variable "dr_instance_class" {
  description = "Instance class for the DR read replica"
  type        = string
  default     = "db.t3.medium"
}

variable "tags" {
  type    = map(string)
  default = {}
}
