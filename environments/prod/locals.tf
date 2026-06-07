locals {
  common_tags = {
    Environment = "prod"
    Project     = "nitin-terraform"
    ManagedBy   = "terraform"
    Owner       = "platform-team"
    CostCenter  = "engineering"
    Compliance  = "pci-dss"
  }
}
