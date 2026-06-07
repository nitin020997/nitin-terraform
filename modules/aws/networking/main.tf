locals {
  # How many NAT gateways to create:
  # prod  -> one per AZ (high availability)
  # dev/staging -> one total (cost saving)
  nat_gateway_count = var.single_nat_gateway ? 1 : length(var.availability_zones)
}

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "vpc-${var.environment}"
  })
}

# -----------------------------------------------------------------------------
# Internet Gateway — allows public subnets to reach the internet
# -----------------------------------------------------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "igw-${var.environment}"
  })
}

# -----------------------------------------------------------------------------
# Public Subnets — resources here get a public IP and can reach internet directly
# -----------------------------------------------------------------------------
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "subnet-public-${var.environment}-${var.availability_zones[count.index]}"
    Tier = "public"
  })
}

# -----------------------------------------------------------------------------
# Private Subnets — no direct internet access, traffic goes through NAT
# Databases, app servers, and internal services live here
# -----------------------------------------------------------------------------
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.tags, {
    Name = "subnet-private-${var.environment}-${var.availability_zones[count.index]}"
    Tier = "private"
  })
}

# -----------------------------------------------------------------------------
# Elastic IPs for NAT Gateways
# NAT gateway needs a static public IP so outbound traffic has a known source
# -----------------------------------------------------------------------------
resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? local.nat_gateway_count : 0
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "eip-nat-${var.environment}-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.main]
}

# -----------------------------------------------------------------------------
# NAT Gateways — allows private subnets to initiate outbound internet traffic
# Lives in public subnet, routes private traffic out
# -----------------------------------------------------------------------------
resource "aws_nat_gateway" "main" {
  count = var.enable_nat_gateway ? local.nat_gateway_count : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.tags, {
    Name = "nat-${var.environment}-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.main]
}

# -----------------------------------------------------------------------------
# Route Tables
# -----------------------------------------------------------------------------

# Public route table — sends all internet traffic through the IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.tags, {
    Name = "rt-public-${var.environment}"
  })
}

# Private route tables — one per NAT gateway
# In prod: one per AZ (if NAT in that AZ fails, only that AZ is affected)
# In dev: one shared (cheaper)
resource "aws_route_table" "private" {
  count  = var.enable_nat_gateway ? local.nat_gateway_count : 1
  vpc_id = aws_vpc.main.id

  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.main[count.index].id
    }
  }

  tags = merge(var.tags, {
    Name = "rt-private-${var.environment}-${count.index + 1}"
  })
}

# -----------------------------------------------------------------------------
# Route Table Associations
# -----------------------------------------------------------------------------

# Associate each public subnet with the public route table
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Associate each private subnet with its route table
# In prod: each AZ gets its own route table (HA)
# In dev: all private subnets share one route table
resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[var.single_nat_gateway ? 0 : count.index].id
}
