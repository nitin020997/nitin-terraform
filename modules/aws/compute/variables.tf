variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs where app servers will be placed"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs where load balancer will be placed"
  type        = list(string)
}

variable "web_sg_id" {
  description = "Security group ID for web/ALB tier"
  type        = string
}

variable "app_sg_id" {
  description = "Security group ID for app tier"
  type        = string
}

variable "instance_profile_name" {
  description = "IAM instance profile name for EC2 instances"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "min_size" {
  description = "Minimum number of instances in the auto-scaling group"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of instances in the auto-scaling group"
  type        = number
  default     = 3
}

variable "desired_capacity" {
  description = "Desired number of instances"
  type        = number
  default     = 1
}

variable "kms_key_id" {
  description = "KMS key ID for EBS volume encryption (null to use AWS managed key)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
