# -----------------------------------------------------------------------------
# Data Sources
# Fetch the latest Amazon Linux 2023 AMI automatically
# Never hardcode AMI IDs — they are region-specific and change with patches
# -----------------------------------------------------------------------------
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# -----------------------------------------------------------------------------
# Launch Template
# Defines HOW instances are created — the ASG uses this as a blueprint
# Using launch templates (not launch configs) — AWS deprecated launch configs
# -----------------------------------------------------------------------------
resource "aws_launch_template" "app" {
  name_prefix   = "lt-${var.environment}-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  # Attach IAM instance profile so the instance can call AWS APIs
  iam_instance_profile {
    name = var.instance_profile_name
  }

  # Attach app tier security group
  vpc_security_group_ids = [var.app_sg_id]

  # EBS root volume — encrypted always
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = var.kms_key_id
      delete_on_termination = true
    }
  }

  # IMDSv2 enforced — prevents SSRF attacks from stealing instance metadata
  # This is a security best practice, especially for fintech
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # Monitoring enabled for prod-like visibility
  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name = "ec2-app-${var.environment}"
    })
  }

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# Application Load Balancer
# Sits in public subnets, forwards traffic to app instances in private subnets
# -----------------------------------------------------------------------------
resource "aws_lb" "app" {
  name               = "alb-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.web_sg_id]
  subnets            = var.public_subnet_ids

  # Deletion protection — prevents accidental terraform destroy in prod
  enable_deletion_protection = var.environment == "prod"

  tags = merge(var.tags, { Name = "alb-${var.environment}" })
}

resource "aws_lb_target_group" "app" {
  name     = "tg-app-${var.environment}"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
  }

  tags = merge(var.tags, { Name = "tg-app-${var.environment}" })
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  # Redirect HTTP to HTTPS — never serve plaintext in fintech
  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# -----------------------------------------------------------------------------
# Auto Scaling Group
# Manages fleet of EC2 instances, replaces unhealthy ones automatically
# -----------------------------------------------------------------------------
resource "aws_autoscaling_group" "app" {
  name                = "asg-app-${var.environment}"
  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = [aws_lb_target_group.app.arn]
  health_check_type   = "ELB"

  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  # Instance refresh — rolling update with zero downtime when launch template changes
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "ec2-app-${var.environment}"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = var.tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# Auto Scaling Policies
# Scale out when CPU > 70%, scale in when CPU < 30%
# Target tracking is simpler and safer than step scaling for most cases
# -----------------------------------------------------------------------------
resource "aws_autoscaling_policy" "cpu_target" {
  name                   = "asg-policy-cpu-${var.environment}"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}
