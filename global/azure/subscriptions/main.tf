# -----------------------------------------------------------------------------
# Azure Subscription Structure
# Azure equivalent of AWS Organizations + Accounts
#
# Hierarchy:
#   Azure AD Tenant (root)
#   └── Management Group (org-level)
#       ├── Platform MG       → shared services, security
#       └── Workloads MG
#           ├── Dev MG        → dev subscription
#           ├── Staging MG    → staging subscription
#           └── Prod MG       → prod subscription
#
# Azure subscriptions = AWS accounts
# Management Groups = AWS Organizational Units
# Azure Policy = AWS SCPs
# -----------------------------------------------------------------------------

# Management Groups
resource "azurerm_management_group" "root" {
  display_name = "nitin-terraform-root"
}

resource "azurerm_management_group" "platform" {
  display_name               = "Platform"
  parent_management_group_id = azurerm_management_group.root.id
}

resource "azurerm_management_group" "workloads" {
  display_name               = "Workloads"
  parent_management_group_id = azurerm_management_group.root.id
}

resource "azurerm_management_group" "workloads_dev" {
  display_name               = "Dev"
  parent_management_group_id = azurerm_management_group.workloads.id
}

resource "azurerm_management_group" "workloads_staging" {
  display_name               = "Staging"
  parent_management_group_id = azurerm_management_group.workloads.id
}

resource "azurerm_management_group" "workloads_prod" {
  display_name               = "Prod"
  parent_management_group_id = azurerm_management_group.workloads.id
}

# -----------------------------------------------------------------------------
# Azure Policy (equivalent of AWS SCPs)
# Applied at management group level — enforces across all subscriptions beneath
# -----------------------------------------------------------------------------

# Require resources to be deployed only in approved regions
resource "azurerm_policy_definition" "allowed_locations" {
  name         = "allowed-locations"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Allowed resource locations"

  policy_rule = jsonencode({
    if = {
      not = {
        field = "location"
        in    = ["eastus", "westus2", "global"]
      }
    }
    then = {
      effect = "Deny"
    }
  })
}

resource "azurerm_management_group_policy_assignment" "allowed_locations_workloads" {
  name                 = "allowed-locations"
  policy_definition_id = azurerm_policy_definition.allowed_locations.id
  management_group_id  = azurerm_management_group.workloads.id
}

# Require tags on all resource groups
resource "azurerm_policy_definition" "require_tags" {
  name         = "require-environment-tag"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Require Environment tag on resource groups"

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "type"
          equals = "Microsoft.Resources/subscriptions/resourceGroups"
        },
        {
          field  = "tags['Environment']"
          exists = "false"
        }
      ]
    }
    then = {
      effect = "Deny"
    }
  })
}

resource "azurerm_management_group_policy_assignment" "require_tags_workloads" {
  name                 = "require-env-tag"
  policy_definition_id = azurerm_policy_definition.require_tags.id
  management_group_id  = azurerm_management_group.workloads.id
}

# -----------------------------------------------------------------------------
# VNet Peering between Dev and Shared Services
# Allows dev workloads to reach shared services (VPN, DNS, artifact registry)
# without going through the internet
# -----------------------------------------------------------------------------
resource "azurerm_virtual_network_peering" "dev_to_shared" {
  name                      = "peer-dev-to-shared"
  resource_group_name       = var.dev_resource_group_name
  virtual_network_name      = var.dev_vnet_name
  remote_virtual_network_id = var.shared_vnet_id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

# Return peering — both sides must be configured
resource "azurerm_virtual_network_peering" "shared_to_dev" {
  name                      = "peer-shared-to-dev"
  resource_group_name       = var.shared_resource_group_name
  virtual_network_name      = var.shared_vnet_name
  remote_virtual_network_id = var.dev_vnet_id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true  # Shared services provides the VPN gateway
  use_remote_gateways          = false
}
