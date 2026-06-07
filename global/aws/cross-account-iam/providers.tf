terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "remote" {
    organization = "nitin-terraform"
    workspaces {
      name = "nitin-terraform-global-iam"
    }
  }
}

# Management account — default provider
provider "aws" {
  region = "us-east-1"

  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    iam = "http://localhost:4566"
    sts = "http://localhost:4566"
  }
}

# Dev account — alias provider
# In real setup: assume_role points to OrganizationAccountAccessRole
# AWS creates this role automatically in every child account
provider "aws" {
  alias  = "dev"
  region = "us-east-1"

  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  # assume_role {
  #   role_arn = "arn:aws:iam::${var.dev_account_id}:role/OrganizationAccountAccessRole"
  # }

  endpoints {
    iam = "http://localhost:4566"
    sts = "http://localhost:4566"
  }
}

# Staging account — alias provider
provider "aws" {
  alias  = "staging"
  region = "us-east-1"

  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    iam = "http://localhost:4566"
    sts = "http://localhost:4566"
  }
}

# Prod account — alias provider
provider "aws" {
  alias  = "prod"
  region = "us-east-1"

  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    iam = "http://localhost:4566"
    sts = "http://localhost:4566"
  }
}
