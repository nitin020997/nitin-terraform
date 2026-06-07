variable "domain_name" {
  description = "Root domain name (e.g. nitin-terraform.com)"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "primary_alb_dns" {
  description = "DNS name of the primary region ALB"
  type        = string
}

variable "primary_alb_zone_id" {
  description = "Route53 hosted zone ID of the primary ALB"
  type        = string
}

variable "dr_alb_dns" {
  description = "DNS name of the DR region ALB"
  type        = string
}

variable "dr_alb_zone_id" {
  description = "Route53 hosted zone ID of the DR ALB"
  type        = string
}

variable "health_check_path" {
  description = "Path for health check endpoint"
  type        = string
  default     = "/health"
}

variable "alarm_sns_topic_arn" {
  description = "SNS topic ARN for health check failure alerts"
  type        = string
  default     = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
