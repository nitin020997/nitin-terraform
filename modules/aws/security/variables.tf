variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "vpc_id" {
  description = "VPC ID where security groups will be created"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block — used to allow internal traffic between resources"
  type        = string
}

variable "enable_kms" {
  description = "Whether to create KMS keys for encryption (disable in dev to save cost)"
  type        = bool
  default     = true
}

variable "allowed_ingress_cidrs" {
  description = "CIDRs allowed to reach public-facing resources (e.g. your office IP)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
