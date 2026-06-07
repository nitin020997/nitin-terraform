# -----------------------------------------------------------------------------
# OCI Compute — Instances + Load Balancer
#
# OCI equivalents of AWS concepts:
#   Compute Instance    = AWS EC2
#   Instance Pool       = AWS Auto Scaling Group
#   Instance Config     = AWS Launch Template
#   Load Balancer       = AWS ALB
#   Backend Set         = AWS Target Group
#
# OCI-specific concepts:
#   Shapes: VM.Standard.E4.Flex = flexible OCPUs/memory (AWS has no direct equivalent)
#   Always Free tier: VM.Standard.E2.1.Micro, 2 instances, always free — best in cloud
#   Dynamic Groups: like AWS resource-based policies for instance IAM
# -----------------------------------------------------------------------------

# Get latest Oracle Linux 8 image
data "oci_core_images" "oracle_linux" {
  compartment_id           = var.compartment_id
  operating_system         = "Oracle Linux"
  operating_system_version = "8"
  shape                    = var.shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# -----------------------------------------------------------------------------
# Instance Configuration (equivalent of AWS Launch Template)
# -----------------------------------------------------------------------------
resource "oci_core_instance_configuration" "app" {
  compartment_id = var.compartment_id
  display_name   = "ic-app-${var.environment}"

  instance_details {
    instance_type = "compute"

    launch_details {
      compartment_id      = var.compartment_id
      display_name        = "app-${var.environment}"
      availability_domain = var.availability_domain

      shape = var.shape

      # Flexible shape configuration
      # OCI allows you to set exact OCPU and memory — more granular than AWS instance sizes
      shape_config {
        ocpus         = var.ocpus
        memory_in_gbs = var.memory_gb
      }

      source_details {
        source_type = "image"
        image_id    = data.oci_core_images.oracle_linux.images[0].id
      }

      create_vnic_details {
        subnet_id             = var.subnet_id
        assign_public_ip      = false # Private instances — behind load balancer
        hostname_label        = "app-${var.environment}"
        nsg_ids               = []
      }

      metadata = {
        # OCI equivalent of AWS SSM — use OCI Bastion service for SSH
        # Never open SSH to 0.0.0.0/0
        user_data = base64encode(<<-EOF
          #!/bin/bash
          # Install OCI monitoring agent
          yum install -y oracle-cloud-agent
          systemctl enable --now oracle-cloud-agent
        EOF
        )
      }

      freeform_tags = var.freeform_tags
    }
  }
}

# -----------------------------------------------------------------------------
# Instance Pool (equivalent of AWS Auto Scaling Group)
# -----------------------------------------------------------------------------
resource "oci_core_instance_pool" "app" {
  compartment_id            = var.compartment_id
  instance_configuration_id = oci_core_instance_configuration.app.id
  size                      = var.instance_count
  display_name              = "pool-app-${var.environment}"

  placement_configurations {
    availability_domain = var.availability_domain
    primary_subnet_id   = var.subnet_id
  }

  freeform_tags = var.freeform_tags
}

# Auto-scaling policy for the instance pool
resource "oci_autoscaling_auto_scaling_configuration" "app" {
  compartment_id = var.compartment_id
  display_name   = "asc-app-${var.environment}"
  is_enabled     = true

  resource {
    type = "instancePool"
    id   = oci_core_instance_pool.app.id
  }

  policies {
    display_name = "cpu-scaling-${var.environment}"
    policy_type  = "threshold"
    capacity {
      initial = var.instance_count
      min     = 1
      max     = var.environment == "prod" ? 10 : 3
    }

    rules {
      action {
        type  = "CHANGE_COUNT_BY"
        value = 1
      }
      display_name = "scale-out"
      metric {
        metric_type = "CPU_UTILIZATION"
        threshold {
          operator = "GT"
          value    = 70
        }
      }
    }

    rules {
      action {
        type  = "CHANGE_COUNT_BY"
        value = -1
      }
      display_name = "scale-in"
      metric {
        metric_type = "CPU_UTILIZATION"
        threshold {
          operator = "LT"
          value    = 30
        }
      }
    }
  }
}

# -----------------------------------------------------------------------------
# OCI Load Balancer
# Flexible shape — you specify bandwidth (10Mbps to 8000Mbps)
# Different from AWS ALB which is fully managed capacity
# -----------------------------------------------------------------------------
resource "oci_load_balancer_load_balancer" "app" {
  compartment_id = var.compartment_id
  display_name   = "lb-app-${var.environment}"
  shape          = "flexible"
  subnet_ids     = [var.public_subnet_id]
  is_private     = false

  shape_details {
    minimum_bandwidth_in_mbps = var.environment == "prod" ? 100 : 10
    maximum_bandwidth_in_mbps = var.environment == "prod" ? 1000 : 100
  }

  freeform_tags = var.freeform_tags
}

resource "oci_load_balancer_backend_set" "app" {
  load_balancer_id = oci_load_balancer_load_balancer.app.id
  name             = "bs-app-${var.environment}"
  policy           = "ROUND_ROBIN"

  health_checker {
    protocol          = "HTTP"
    url_path          = "/health"
    port              = 8080
    interval_ms       = 10000
    timeout_in_millis = 3000
    retries           = 3
    return_code       = 200
  }
}

resource "oci_load_balancer_listener" "https" {
  load_balancer_id         = oci_load_balancer_load_balancer.app.id
  name                     = "listener-https-${var.environment}"
  default_backend_set_name = oci_load_balancer_backend_set.app.name
  port                     = 443
  protocol                 = "HTTP" # HTTPS requires certificate_ids
}
