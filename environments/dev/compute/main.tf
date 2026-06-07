# -----------------------------------------------------------------------------
# Remote State — read networking outputs without sharing state
#
# This is the key Phase 2 pattern:
# Compute team reads what networking team deployed via remote state data source.
# They cannot modify networking state. Networking team cannot modify compute state.
# Teams are decoupled — each applies independently.
# -----------------------------------------------------------------------------
data "terraform_remote_state" "networking" {
  backend = "remote"

  config = {
    organization = "nitin-terraform"
    workspaces = {
      name = "nitin-terraform-dev-networking"
    }
  }
}

data "terraform_remote_state" "security" {
  backend = "remote"

  config = {
    organization = "nitin-terraform"
    workspaces = {
      name = "nitin-terraform-dev-security"
    }
  }
}

module "compute" {
  source = "../../../modules/aws/compute"

  environment = "dev"

  # Consumed from networking team's state — never hardcoded
  vpc_id             = data.terraform_remote_state.networking.outputs.vpc_id
  private_subnet_ids = data.terraform_remote_state.networking.outputs.private_subnet_ids
  public_subnet_ids  = data.terraform_remote_state.networking.outputs.public_subnet_ids

  # Consumed from security team's state
  web_sg_id             = data.terraform_remote_state.security.outputs.web_sg_id
  app_sg_id             = data.terraform_remote_state.security.outputs.app_sg_id
  instance_profile_name = data.terraform_remote_state.security.outputs.ec2_instance_profile_name

  instance_type    = "t3.micro"
  min_size         = 1
  max_size         = 2
  desired_capacity = 1
  kms_key_id       = null

  tags = {
    Environment = "dev"
    Project     = "nitin-terraform"
    ManagedBy   = "terraform"
    Team        = "compute"
    Layer       = "compute"
  }
}
