# -----------------------------------------------------------------------------
# VPC Network
# GCP VPCs are GLOBAL — one VPC spans all regions
# This is fundamentally different from AWS where VPCs are regional
# Subnets within the VPC are regional
# -----------------------------------------------------------------------------
resource "google_compute_network" "main" {
  name                    = "vpc-${var.environment}-${var.vpc_name}"
  project                 = var.project_id
  auto_create_subnetworks = false # Always false — never use auto mode in production
  routing_mode            = "GLOBAL"
}

# -----------------------------------------------------------------------------
# Subnet
# GCP subnets support secondary IP ranges — used for GKE pods and services
# Pre-allocating these ranges now (even without GKE) means you won't need
# to recreate the subnet when you add GKE later
# -----------------------------------------------------------------------------
resource "google_compute_subnetwork" "main" {
  name          = "subnet-${var.environment}-${var.region}"
  project       = var.project_id
  region        = var.region
  network       = google_compute_network.main.id
  ip_cidr_range = var.subnet_cidr

  # Allow VMs without external IPs to reach Google APIs (Cloud Storage, BigQuery, etc.)
  private_ip_google_access = var.enable_private_google_access

  # Secondary ranges for future GKE pods and services
  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# -----------------------------------------------------------------------------
# Cloud Router + Cloud NAT
# GCP equivalent of AWS NAT Gateway
# Cloud Router handles BGP, Cloud NAT uses it for outbound internet
# Must be created together — Cloud NAT requires a Cloud Router
# -----------------------------------------------------------------------------
resource "google_compute_router" "main" {
  name    = "router-${var.environment}"
  project = var.project_id
  region  = var.region
  network = google_compute_network.main.id
}

resource "google_compute_router_nat" "main" {
  name                               = "nat-${var.environment}"
  project                            = var.project_id
  router                             = google_compute_router.main.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# -----------------------------------------------------------------------------
# Firewall Rules
# GCP firewall rules are attached to the VPC, not to subnets or instances
# Target tags let you apply rules to specific instances (like AWS security groups)
# -----------------------------------------------------------------------------

# Allow HTTPS from internet to instances tagged "web"
resource "google_compute_firewall" "allow_https" {
  name    = "fw-allow-https-${var.environment}"
  project = var.project_id
  network = google_compute_network.main.id

  allow {
    protocol = "tcp"
    ports    = ["443", "80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web-${var.environment}"]
}

# Allow internal traffic within the VPC
resource "google_compute_firewall" "allow_internal" {
  name    = "fw-allow-internal-${var.environment}"
  project = var.project_id
  network = google_compute_network.main.id

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [var.subnet_cidr]
}

# Allow IAP (Identity-Aware Proxy) SSH — GCP's equivalent of AWS SSM Session Manager
# Never open port 22 to 0.0.0.0/0 in GCP — use IAP instead
resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "fw-allow-iap-ssh-${var.environment}"
  project = var.project_id
  network = google_compute_network.main.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # IAP's IP range — only Google's IAP service can initiate SSH
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["iap-ssh-${var.environment}"]
}
