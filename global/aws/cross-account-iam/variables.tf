variable "dev_account_id" {
  description = "AWS account ID for the dev workload account"
  type        = string
}

variable "staging_account_id" {
  description = "AWS account ID for the staging workload account"
  type        = string
}

variable "prod_account_id" {
  description = "AWS account ID for the prod workload account"
  type        = string
}
