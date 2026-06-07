variable "primary_region" {
  description = "Primary AWS region (serves live traffic)"
  type        = string
  default     = "us-east-1"
}

variable "dr_region" {
  description = "Disaster recovery region (warm standby)"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "primary_vpc_cidr" {
  description = "VPC CIDR for primary region"
  type        = string
  default     = "10.2.0.0/16"
}

variable "dr_vpc_cidr" {
  description = "VPC CIDR for DR region — must not overlap with primary"
  type        = string
  default     = "10.3.0.0/16"
}

variable "primary_azs" {
  description = "AZs in primary region"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "dr_azs" {
  description = "AZs in DR region"
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b"]
}

variable "tags" {
  type    = map(string)
  default = {}
}
