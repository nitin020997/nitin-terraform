variable "environment" { type = string }
variable "monthly_budget_usd" { type = string; default = "500" }
variable "alert_email" { type = string }
variable "tags" { type = map(string); default = {} }
