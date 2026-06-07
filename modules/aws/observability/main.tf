resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "dashboard-${var.environment}"
  dashboard_body = jsonencode({
    widgets = [
      { type = "metric", properties = { title = "ALB Request Count", metrics = [["AWS/ApplicationELB", "RequestCount"]], period = 60, stat = "Sum" } },
      { type = "metric", properties = { title = "ALB 5xx Errors", metrics = [["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count"]], period = 60, stat = "Sum" } },
      { type = "metric", properties = { title = "ASG CPU", metrics = [["AWS/EC2", "CPUUtilization"]], period = 60, stat = "Average" } },
      { type = "metric", properties = { title = "RDS CPU", metrics = [["AWS/RDS", "CPUUtilization"]], period = 60, stat = "Average" } },
      { type = "metric", properties = { title = "RDS Connections", metrics = [["AWS/RDS", "DatabaseConnections"]], period = 60, stat = "Average" } },
    ]
  })
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "alb-5xx-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = var.environment == "prod" ? 10 : 50
  alarm_description   = "ALB 5xx error rate too high"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : []
  tags                = var.tags
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "rds-cpu-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RDS CPU too high — consider scaling instance class"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : []
  tags                = var.tags
}

resource "aws_cloudwatch_metric_alarm" "rds_storage" {
  alarm_name          = "rds-storage-${var.environment}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 10737418240 # 10 GB in bytes
  alarm_description   = "RDS free storage below 10GB"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : []
  tags                = var.tags
}

resource "aws_sns_topic" "alerts" {
  count = var.sns_topic_arn == null ? 1 : 0
  name  = "alerts-${var.environment}"
  tags  = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alert_email != null && var.sns_topic_arn == null ? 1 : 0
  topic_arn = aws_sns_topic.alerts[0].arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/app/${var.environment}"
  retention_in_days = var.environment == "prod" ? 365 : 30
  tags              = var.tags
}
