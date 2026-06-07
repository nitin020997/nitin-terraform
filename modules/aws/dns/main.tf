# -----------------------------------------------------------------------------
# Route53 Hosted Zone
# DNS is global — one zone serves all regions
# -----------------------------------------------------------------------------
resource "aws_route53_zone" "main" {
  name = var.domain_name
  tags = var.tags
}

# -----------------------------------------------------------------------------
# Health Checks
# Route53 health checkers are distributed globally — they check from ~15 locations
# Threshold: 3 consecutive failures = unhealthy (avoids flapping on transient issues)
#
# Architect note: health checks must hit the SAME endpoint your users hit.
# If your ALB serves /health but your app is broken, the health check passes.
# Design your /health endpoint to check DB connectivity, cache, dependencies.
# -----------------------------------------------------------------------------
resource "aws_route53_health_check" "primary" {
  fqdn              = var.primary_alb_dns
  port              = 443
  type              = "HTTPS"
  resource_path     = var.health_check_path
  failure_threshold = 3
  request_interval  = 30

  tags = merge(var.tags, {
    Name = "hc-primary-${var.environment}"
    Role = "primary"
  })
}

resource "aws_route53_health_check" "dr" {
  fqdn              = var.dr_alb_dns
  port              = 443
  type              = "HTTPS"
  resource_path     = var.health_check_path
  failure_threshold = 3
  request_interval  = 30

  tags = merge(var.tags, {
    Name = "hc-dr-${var.environment}"
    Role = "dr-standby"
  })
}

# -----------------------------------------------------------------------------
# CloudWatch Alarm on health check
# Route53 can trigger alarms when health checks fail
# This gives you visibility before failover happens — and after
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "primary_health" {
  alarm_name          = "route53-hc-primary-${var.environment}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1

  dimensions = {
    HealthCheckId = aws_route53_health_check.primary.id
  }

  alarm_description = "Primary region health check failing — failover may be in progress"
  alarm_actions     = var.alarm_sns_topic_arn != null ? [var.alarm_sns_topic_arn] : []
  ok_actions        = var.alarm_sns_topic_arn != null ? [var.alarm_sns_topic_arn] : []

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Failover DNS Records
#
# PRIMARY record: serves traffic when healthy, associated with health check
# SECONDARY record: only receives traffic when primary health check fails
#
# How it works:
# 1. Both records have the same name (api.nitin-terraform.com)
# 2. Route53 returns PRIMARY when its health check passes
# 3. When primary fails 3 consecutive checks, Route53 returns SECONDARY
# 4. TTL is short (60s) so clients switch quickly
#
# RTO for DNS: TTL (60s) + health check interval (30s) × failure threshold (3) = ~150 seconds
# -----------------------------------------------------------------------------
resource "aws_route53_record" "primary" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "api.${var.domain_name}"
  type    = "A"

  failover_routing_policy {
    type = "PRIMARY"
  }

  set_identifier = "primary"
  health_check_id = aws_route53_health_check.primary.id

  alias {
    name                   = var.primary_alb_dns
    zone_id                = var.primary_alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "dr" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "api.${var.domain_name}"
  type    = "A"

  failover_routing_policy {
    type = "SECONDARY"
  }

  set_identifier = "dr"
  health_check_id = aws_route53_health_check.dr.id

  alias {
    name                   = var.dr_alb_dns
    zone_id                = var.dr_alb_zone_id
    evaluate_target_health = true
  }
}

# -----------------------------------------------------------------------------
# Latency-based routing for static assets (separate record)
# Users get routed to the closest region for static content
# Dynamic API always goes to primary (for data consistency)
# -----------------------------------------------------------------------------
resource "aws_route53_record" "static_primary" {
  zone_id        = aws_route53_zone.main.zone_id
  name           = "static.${var.domain_name}"
  type           = "A"
  set_identifier = "static-primary"

  latency_routing_policy {
    region = "us-east-1"
  }

  alias {
    name                   = var.primary_alb_dns
    zone_id                = var.primary_alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "static_dr" {
  zone_id        = aws_route53_zone.main.zone_id
  name           = "static.${var.domain_name}"
  type           = "A"
  set_identifier = "static-dr"

  latency_routing_policy {
    region = "us-west-2"
  }

  alias {
    name                   = var.dr_alb_dns
    zone_id                = var.dr_alb_zone_id
    evaluate_target_health = true
  }
}
