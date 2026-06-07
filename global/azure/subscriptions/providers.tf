terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  backend "remote" {
    organization = "nitin-terraform"
    workspaces {
      name = "nitin-terraform-global-azure"
    }
  }
}

provider "azurerm" {
  features {}
  # In real setup: use_oidc = true for GitHub Actions OIDC auth
}
