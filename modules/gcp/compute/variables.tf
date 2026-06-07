variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "network_name" {
  description = "VPC network name"
  type        = string
}

variable "subnet_name" {
  description = "Subnet name for instances"
  type        = string
}

variable "machine_type" {
  description = "GCP machine type"
  type        = string
  default     = "e2-micro"
}

variable "min_replicas" {
  description = "Minimum instances in the managed instance group"
  type        = number
  default     = 1
}

variable "max_replicas" {
  description = "Maximum instances in the managed instance group"
  type        = number
  default     = 3
}

variable "web_firewall_tag" {
  description = "Network tag for web-tier firewall rules (from networking module output)"
  type        = string
}

variable "labels" {
  description = "GCP labels (equivalent of AWS tags)"
  type        = map(string)
  default     = {}
}
