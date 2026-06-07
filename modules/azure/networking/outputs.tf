output "resource_group_name" {
  description = "Name of the Azure Resource Group"
  value       = azurerm_resource_group.main.name
}

output "vnet_id" {
  description = "ID of the Virtual Network"
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "Name of the Virtual Network"
  value       = azurerm_virtual_network.main.name
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = azurerm_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = azurerm_subnet.private[*].id
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway"
  value       = azurerm_nat_gateway.main.id
}
