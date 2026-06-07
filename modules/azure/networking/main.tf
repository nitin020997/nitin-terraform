# -----------------------------------------------------------------------------
# Resource Group
# Azure-specific concept: logical container for all related resources
# AWS equivalent: no direct equivalent (AWS uses tags for grouping)
# Deleting a resource group deletes EVERYTHING inside it — handle with care
# -----------------------------------------------------------------------------
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# -----------------------------------------------------------------------------
# Virtual Network (VNet)
# Azure equivalent of AWS VPC
# -----------------------------------------------------------------------------
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = [var.vnet_cidr]

  tags = merge(var.tags, { Name = "vnet-${var.environment}" })
}

# -----------------------------------------------------------------------------
# Public Subnets
# Azure subnets don't have a map_public_ip setting like AWS
# Public IP assignment is controlled at the NIC/resource level
# -----------------------------------------------------------------------------
resource "azurerm_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  name                 = "subnet-public-${var.environment}-${count.index + 1}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.public_subnet_cidrs[count.index]]
}

# -----------------------------------------------------------------------------
# Private Subnets
# -----------------------------------------------------------------------------
resource "azurerm_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  name                 = "subnet-private-${var.environment}-${count.index + 1}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.private_subnet_cidrs[count.index]]
}

# -----------------------------------------------------------------------------
# Network Security Groups (NSG)
# Azure equivalent of AWS Security Groups
# Key difference: NSGs can be attached to subnets OR NICs
# Attaching to subnet = applies to all resources in subnet (recommended)
# -----------------------------------------------------------------------------
resource "azurerm_network_security_group" "public" {
  name                = "nsg-public-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "allow-https"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-http"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = merge(var.tags, { Name = "nsg-public-${var.environment}" })
}

resource "azurerm_network_security_group" "private" {
  name                = "nsg-private-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "allow-vnet-inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "deny-internet-inbound"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  tags = merge(var.tags, { Name = "nsg-private-${var.environment}" })
}

# Associate NSGs with subnets
resource "azurerm_subnet_network_security_group_association" "public" {
  count = length(azurerm_subnet.public)

  subnet_id                 = azurerm_subnet.public[count.index].id
  network_security_group_id = azurerm_network_security_group.public.id
}

resource "azurerm_subnet_network_security_group_association" "private" {
  count = length(azurerm_subnet.private)

  subnet_id                 = azurerm_subnet.private[count.index].id
  network_security_group_id = azurerm_network_security_group.private.id
}

# -----------------------------------------------------------------------------
# NAT Gateway (Azure)
# Azure NAT Gateway is a separate resource, unlike AWS where it's tied to a subnet
# Provides outbound internet for private subnets
# -----------------------------------------------------------------------------
resource "azurerm_public_ip" "nat" {
  name                = "pip-nat-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.tags
}

resource "azurerm_nat_gateway" "main" {
  name                = "nat-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = "Standard"

  tags = var.tags
}

resource "azurerm_nat_gateway_public_ip_association" "main" {
  nat_gateway_id       = azurerm_nat_gateway.main.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

resource "azurerm_subnet_nat_gateway_association" "private" {
  count = length(azurerm_subnet.private)

  subnet_id      = azurerm_subnet.private[count.index].id
  nat_gateway_id = azurerm_nat_gateway.main.id
}
