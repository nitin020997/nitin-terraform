# FinOps — Budget alerts + cost attribution per environment
resource "aws_budgets_budget" "environment" {
  name         = "budget-${var.environment}"
  budget_type  = "COST"
  limit_amount = var.monthly_budget_usd
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # Filter costs to this environment only via tags
  cost_filter {
    name   = "TagKeyValue"
    values = ["user:Environment$${var.environment}"]
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    notification_type         = "FORECASTED"
    subscriber_email_addresses = [var.alert_email]
  }
}

# Cost anomaly detection — alerts when spend pattern deviates from baseline
resource "aws_ce_anomaly_monitor" "environment" {
  name              = "anomaly-${var.environment}"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"
}

resource "aws_ce_anomaly_subscription" "environment" {
  name      = "anomaly-sub-${var.environment}"
  frequency = "DAILY"

  monitor_arn_list = [aws_ce_anomaly_monitor.environment.arn]

  subscriber {
    type    = "EMAIL"
    address = var.alert_email
  }

  # Alert when anomaly exceeds $50 in a day
  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
      values        = ["50"]
      match_options = ["GREATER_THAN_OR_EQUAL"]
    }
  }
}
