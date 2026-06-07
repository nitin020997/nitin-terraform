# -----------------------------------------------------------------------------
# Multi-Region Networking — Active-Passive Pattern
#
# Primary region: us-east-1 — serves all live traffic
# DR region:      us-west-2 — warm standby, promoted during failover
#
# Why Active-Passive for fintech?
# - Data consistency: one write region avoids split-brain on financial transactions
# - Cost: DR region runs at ~30% capacity until failover
# - Simpler: no need for global load balancing or conflict resolution
# - RTO: ~5-10 minutes (acceptable for most fintech SLAs)
# -----------------------------------------------------------------------------

# Primary region networking
module "networking_primary" {
  source = "../networking"

  environment        = var.environment
  vpc_cidr           = var.primary_vpc_cidr
  availability_zones = var.primary_azs

  public_subnet_cidrs = [
    cidrsubnet(var.primary_vpc_cidr, 8, 1),
    cidrsubnet(var.primary_vpc_cidr, 8, 2),
    cidrsubnet(var.primary_vpc_cidr, 8, 3),
  ]
  private_subnet_cidrs = [
    cidrsubnet(var.primary_vpc_cidr, 8, 10),
    cidrsubnet(var.primary_vpc_cidr, 8, 11),
    cidrsubnet(var.primary_vpc_cidr, 8, 12),
  ]

  enable_nat_gateway = true
  single_nat_gateway = false

  tags = merge(var.tags, { Region = var.primary_region, Role = "primary" })
}

# DR region networking — smaller footprint
module "networking_dr" {
  source = "../networking"

  providers = {
    aws = aws.dr
  }

  environment        = "${var.environment}-dr"
  vpc_cidr           = var.dr_vpc_cidr
  availability_zones = var.dr_azs

  public_subnet_cidrs = [
    cidrsubnet(var.dr_vpc_cidr, 8, 1),
    cidrsubnet(var.dr_vpc_cidr, 8, 2),
  ]
  private_subnet_cidrs = [
    cidrsubnet(var.dr_vpc_cidr, 8, 10),
    cidrsubnet(var.dr_vpc_cidr, 8, 11),
  ]

  # DR: single NAT gateway — not full HA until failover is declared
  enable_nat_gateway = true
  single_nat_gateway = true

  tags = merge(var.tags, { Region = var.dr_region, Role = "dr-standby" })
}

# -----------------------------------------------------------------------------
# VPC Peering — primary to DR
# Allows RDS replication traffic to flow privately between regions
# Without this, replication goes over the internet (slower, costs more, less secure)
# -----------------------------------------------------------------------------
resource "aws_vpc_peering_connection" "primary_to_dr" {
  vpc_id        = module.networking_primary.vpc_id
  peer_vpc_id   = module.networking_dr.vpc_id
  peer_region   = var.dr_region
  auto_accept   = false

  tags = merge(var.tags, { Name = "peer-${var.environment}-primary-to-dr" })
}

# Accept the peering request in the DR region
resource "aws_vpc_peering_connection_accepter" "dr" {
  provider                  = aws.dr
  vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_dr.id
  auto_accept               = true

  tags = merge(var.tags, { Name = "peer-${var.environment}-dr-accepter" })
}

# Route from primary private subnets to DR via peering
resource "aws_route" "primary_to_dr" {
  route_table_id            = module.networking_primary.private_route_table_ids[0]
  destination_cidr_block    = var.dr_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_dr.id
}

# Route from DR private subnets to primary via peering
resource "aws_route" "dr_to_primary" {
  provider                  = aws.dr
  route_table_id            = module.networking_dr.private_route_table_ids[0]
  destination_cidr_block    = var.primary_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_dr.id
}
