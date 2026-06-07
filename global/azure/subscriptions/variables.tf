variable "dev_resource_group_name" {
  description = "Resource group name in dev subscription"
  type        = string
}

variable "dev_vnet_name" {
  description = "VNet name in dev subscription"
  type        = string
}

variable "dev_vnet_id" {
  description = "VNet resource ID in dev subscription"
  type        = string
}

variable "shared_resource_group_name" {
  description = "Resource group name in shared services subscription"
  type        = string
}

variable "shared_vnet_name" {
  description = "VNet name in shared services subscription"
  type        = string
}

variable "shared_vnet_id" {
  description = "VNet resource ID in shared services subscription"
  type        = string
}
