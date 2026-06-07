terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Terraform Cloud backend — state stored remotely, never on local disk
  # Switch to localstack by commenting this out and using local backend during dev
  backend "remote" {
    organization = "nitin-terraform"

    workspaces {
      name = "nitin-terraform-dev"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  # LocalStack override — point AWS provider to local emulator
  # Comment these out when using real AWS
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    ec2 = "http://localhost:4566"
    s3  = "http://localhost:4566"
    iam = "http://localhost:4566"
    vpc = "http://localhost:4566"
  }
}
