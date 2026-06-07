output "sns_topic_arn" {
  value = var.sns_topic_arn != null ? var.sns_topic_arn : aws_sns_topic.alerts[0].arn
}
output "log_group_name" {
  value = aws_cloudwatch_log_group.app.name
}
