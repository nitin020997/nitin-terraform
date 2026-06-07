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
      name = "nitin-terraform-dev-compute"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    ec2                = "http://localhost:4566"
    elasticloadbalancing = "http://localhost:4566"
    autoscaling        = "http://localhost:4566"
    iam                = "http://localhost:4566"
  }
}
