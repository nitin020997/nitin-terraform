# -----------------------------------------------------------------------------
# GCP Compute — Managed Instance Group + Load Balancer
#
# GCP equivalents of AWS concepts:
#   Instance Template    = AWS Launch Template
#   Managed Instance Group (MIG) = AWS Auto Scaling Group
#   Backend Service      = AWS Target Group
#   URL Map + Proxy      = AWS ALB listener rules
#   Forwarding Rule      = AWS ALB
#
# Key GCP difference: autoscaling and load balancing are at the project level,
# not tied to a VPC. The load balancer itself is global (not regional like ALB).
# -----------------------------------------------------------------------------

# Service account for compute instances
# GCP equivalent of AWS IAM instance profile
resource "google_service_account" "app" {
  project      = var.project_id
  account_id   = "sa-app-${var.environment}"
  display_name = "App service account for ${var.environment}"
}

# Grant permissions to read from Secret Manager (GCP equivalent of Secrets Manager)
resource "google_project_iam_member" "app_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.app.email}"
}

# Grant permissions to write logs and metrics
resource "google_project_iam_member" "app_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.app.email}"
}

resource "google_project_iam_member" "app_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.app.email}"
}

# -----------------------------------------------------------------------------
# Instance Template
# Defines machine type, disk, OS, service account, network tags
# -----------------------------------------------------------------------------
resource "google_compute_instance_template" "app" {
  project      = var.project_id
  name_prefix  = "tmpl-app-${var.environment}-"
  machine_type = var.machine_type
  region       = var.region

  disk {
    source_image = "projects/debian-cloud/global/images/family/debian-12"
    auto_delete  = true
    boot         = true
    disk_size_gb = 20
    disk_type    = "pd-ssd"

    # Always encrypt disks — GCP encrypts by default but using CMEK
    # (Customer Managed Encryption Key) is required for compliance
    # disk_encryption_key { kms_key_self_link = var.kms_key }
  }

  network_interface {
    network    = var.network_name
    subnetwork = var.subnet_name
    # No access_config = no public IP — instances only reachable via load balancer
  }

  service_account {
    email  = google_service_account.app.email
    scopes = ["cloud-platform"] # Broad scope — service account IAM controls actual access
  }

  # Network tags — control which firewall rules apply to this instance
  tags = [var.web_firewall_tag]

  metadata = {
    # Enable OS Login — GCP equivalent of AWS SSM Session Manager
    # Ties SSH access to Google identity, no SSH keys to manage
    enable-oslogin = "TRUE"
  }

  labels = var.labels

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# Managed Instance Group (MIG)
# Regional MIG — distributes instances across all AZs in the region
# This is superior to zonal MIG for prod (survives AZ failure)
# -----------------------------------------------------------------------------
resource "google_compute_region_instance_group_manager" "app" {
  project            = var.project_id
  name               = "mig-app-${var.environment}"
  region             = var.region
  base_instance_name = "app-${var.environment}"

  version {
    instance_template = google_compute_instance_template.app.id
  }

  # Named port — load balancer uses this to send traffic to instances
  named_port {
    name = "http"
    port = 8080
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.app.id
    initial_delay_sec = 120 # Allow instance to boot before health checks start
  }

  update_policy {
    type                  = "PROACTIVE"       # Rolling update (vs OPPORTUNISTIC = only on scale events)
    minimal_action        = "REPLACE"
    max_surge_fixed       = 1                 # Add 1 extra instance during rolling update
    max_unavailable_fixed = 0                 # Never take an instance offline before replacement is ready
  }
}

# Autoscaler
resource "google_compute_region_autoscaler" "app" {
  project = var.project_id
  name    = "as-app-${var.environment}"
  region  = var.region
  target  = google_compute_region_instance_group_manager.app.id

  autoscaling_policy {
    min_replicas    = var.min_replicas
    max_replicas    = var.max_replicas
    cooldown_period = 60

    cpu_utilization {
      target = 0.7
    }
  }
}

# Health check for auto-healing and load balancer
resource "google_compute_health_check" "app" {
  project = var.project_id
  name    = "hc-app-${var.environment}"

  http_health_check {
    port         = 8080
    request_path = "/health"
  }

  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3
}

# -----------------------------------------------------------------------------
# Global HTTP(S) Load Balancer
# GCP load balancers are GLOBAL — one LB serves all regions
# Traffic is routed to the nearest healthy backend
# This is different from AWS ALB which is regional
# -----------------------------------------------------------------------------
resource "google_compute_backend_service" "app" {
  project               = var.project_id
  name                  = "bs-app-${var.environment}"
  protocol              = "HTTP"
  port_name             = "http"
  load_balancing_scheme = "EXTERNAL"
  health_checks         = [google_compute_health_check.app.id]

  backend {
    group           = google_compute_region_instance_group_manager.app.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

resource "google_compute_url_map" "app" {
  project         = var.project_id
  name            = "urlmap-app-${var.environment}"
  default_service = google_compute_backend_service.app.id
}

resource "google_compute_target_https_proxy" "app" {
  project  = var.project_id
  name     = "proxy-app-${var.environment}"
  url_map  = google_compute_url_map.app.id

  # SSL certificate — use Google-managed cert in real setup
  ssl_certificates = []
}

resource "google_compute_global_forwarding_rule" "app" {
  project               = var.project_id
  name                  = "fr-app-${var.environment}"
  target                = google_compute_target_https_proxy.app.id
  port_range            = "443"
  load_balancing_scheme = "EXTERNAL"
}
