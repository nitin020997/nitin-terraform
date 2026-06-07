terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Separate workspace — org config lives in its own state
  # Never mix org-level config with workload state
  backend "remote" {
    organization = "nitin-terraform"
    workspaces {
      name = "nitin-terraform-global-org"
    }
  }
}

# This provider uses the Management Account credentials
# In real setup: this is a separate AWS profile/role from workload accounts
provider "aws" {
  region = "us-east-1"

  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    organizations = "http://localhost:4566"
    iam           = "http://localhost:4566"
    sts           = "http://localhost:4566"
  }
}
