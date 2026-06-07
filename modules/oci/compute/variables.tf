variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "compartment_id" {
  description = "OCI Compartment OCID"
  type        = string
}

variable "availability_domain" {
  description = "OCI Availability Domain"
  type        = string
}

variable "subnet_id" {
  description = "Subnet OCID where instances will be placed"
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet OCID for the load balancer"
  type        = string
}

variable "shape" {
  description = "OCI compute shape (instance type)"
  type        = string
  default     = "VM.Standard.E4.Flex"
}

variable "ocpus" {
  description = "Number of OCPUs for flexible shapes"
  type        = number
  default     = 1
}

variable "memory_gb" {
  description = "Memory in GB for flexible shapes"
  type        = number
  default     = 4
}

variable "instance_count" {
  description = "Number of compute instances"
  type        = number
  default     = 1
}

variable "freeform_tags" {
  type    = map(string)
  default = {}
}
