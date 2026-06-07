# -----------------------------------------------------------------------------
# Dev Networking — owns its own state
# Workspace: nitin-terraform-dev-networking
#
# Architect decision: split state by layer (networking/compute/database)
# This means the networking team can update VPCs without any risk to
# the compute or database state. Each team has sovereignty over their layer.
# -----------------------------------------------------------------------------

module "networking" {
  source = "../../../modules/aws/networking"

  environment        = "dev"
  vpc_cidr           = "10.0.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b"]

  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    Environment = "dev"
    Project     = "nitin-terraform"
    ManagedBy   = "terraform"
    Team        = "networking"
    Layer       = "networking"
  }
}
