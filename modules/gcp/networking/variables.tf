variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

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
  description = "GCP region for subnets"
  type        = string
  default     = "us-central1"
}

variable "vpc_name" {
  description = "Name of the VPC network"
  type        = string
}

variable "subnet_cidr" {
  description = "CIDR for the primary subnet"
  type        = string
  default     = "10.3.0.0/20"
}

variable "pods_cidr" {
  description = "Secondary CIDR for GKE pods (pre-allocate even if not using GKE yet)"
  type        = string
  default     = "10.3.16.0/20"
}

variable "services_cidr" {
  description = "Secondary CIDR for GKE services"
  type        = string
  default     = "10.3.32.0/20"
}

variable "enable_private_google_access" {
  description = "Allow VMs without public IPs to reach Google APIs"
  type        = bool
  default     = true
}

variable "labels" {
  description = "Labels to apply to all resources (GCP equivalent of tags)"
  type        = map(string)
  default     = {}
}
