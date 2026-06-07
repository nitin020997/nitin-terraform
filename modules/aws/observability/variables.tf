variable "environment" { type = string }
variable "sns_topic_arn" { type = string; default = null }
variable "alert_email" { type = string; default = null }
variable "tags" { type = map(string); default = {} }
