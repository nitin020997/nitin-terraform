# -----------------------------------------------------------------------------
# Virtual Cloud Network (VCN)
# OCI equivalent of AWS VPC / Azure VNet / GCP VPC
# OCI-specific: VCN is regional (like AWS), not global (like GCP)
# -----------------------------------------------------------------------------
resource "oci_core_vcn" "main" {
  compartment_id = var.compartment_id
  cidr_blocks    = [var.vcn_cidr]
  display_name   = "vcn-${var.environment}"
  dns_label      = "vcn${var.environment}"

  freeform_tags = var.freeform_tags
}

# -----------------------------------------------------------------------------
# Internet Gateway
# OCI equivalent of AWS Internet Gateway
# Required for public subnets to reach the internet
# -----------------------------------------------------------------------------
resource "oci_core_internet_gateway" "main" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "igw-${var.environment}"
  enabled        = true

  freeform_tags = var.freeform_tags
}

# -----------------------------------------------------------------------------
# NAT Gateway
# OCI NAT Gateway — allows private subnet outbound internet without public IPs
# OCI-specific: NAT gateway is a standalone resource (like Azure, unlike AWS
# where it needs an EIP allocated separately)
# -----------------------------------------------------------------------------
resource "oci_core_nat_gateway" "main" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "nat-${var.environment}"

  freeform_tags = var.freeform_tags
}

# -----------------------------------------------------------------------------
# Service Gateway
# OCI-specific resource — no AWS/Azure equivalent
# Allows private instances to reach OCI services (Object Storage, etc.)
# without going through the internet, using OCI's internal backbone
# -----------------------------------------------------------------------------
data "oci_core_services" "all" {}

resource "oci_core_service_gateway" "main" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "sgw-${var.environment}"

  services {
    service_id = data.oci_core_services.all.services[0].id
  }

  freeform_tags = var.freeform_tags
}

# -----------------------------------------------------------------------------
# Route Tables
# OCI route tables work similarly to AWS, but are attached to subnets explicitly
# -----------------------------------------------------------------------------

# Public route table — internet bound traffic goes through IGW
resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "rt-public-${var.environment}"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.main.id
  }

  freeform_tags = var.freeform_tags
}

# Private route table — outbound via NAT, OCI services via Service Gateway
resource "oci_core_route_table" "private" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "rt-private-${var.environment}"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.main.id
  }

  route_rules {
    destination       = "all-iad-services-in-oracle-services-network"
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.main.id
  }

  freeform_tags = var.freeform_tags
}

# -----------------------------------------------------------------------------
# Security Lists
# OCI equivalent of AWS NACLs (not security groups)
# OCI also has Network Security Groups (NSGs) which are like AWS security groups
# Best practice: use NSGs for instance-level rules, Security Lists for subnet-level
# -----------------------------------------------------------------------------
resource "oci_core_security_list" "public" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "sl-public-${var.environment}"

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"

    tcp_options {
      min = 443
      max = 443
    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"

    tcp_options {
      min = 80
      max = 80
    }
  }

  freeform_tags = var.freeform_tags
}

resource "oci_core_security_list" "private" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "sl-private-${var.environment}"

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  ingress_security_rules {
    protocol = "all"
    source   = var.vcn_cidr
  }

  freeform_tags = var.freeform_tags
}

# -----------------------------------------------------------------------------
# Subnets
# -----------------------------------------------------------------------------
resource "oci_core_subnet" "public" {
  compartment_id    = var.compartment_id
  vcn_id            = oci_core_vcn.main.id
  cidr_block        = var.public_subnet_cidr
  display_name      = "subnet-public-${var.environment}"
  dns_label         = "pub${var.environment}"
  route_table_id    = oci_core_route_table.public.id
  security_list_ids = [oci_core_security_list.public.id]

  prohibit_public_ip_on_vnic = false

  freeform_tags = var.freeform_tags
}

resource "oci_core_subnet" "private" {
  compartment_id    = var.compartment_id
  vcn_id            = oci_core_vcn.main.id
  cidr_block        = var.private_subnet_cidr
  display_name      = "subnet-private-${var.environment}"
  dns_label         = "priv${var.environment}"
  route_table_id    = oci_core_route_table.private.id
  security_list_ids = [oci_core_security_list.private.id]

  prohibit_public_ip_on_vnic = true

  freeform_tags = var.freeform_tags
}
