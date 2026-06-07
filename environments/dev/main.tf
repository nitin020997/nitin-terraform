module "networking" {
  source = "../../modules/aws/networking"

  environment        = "dev"
  vpc_cidr           = "10.0.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b"]

  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]

  # Dev saves cost: single NAT gateway instead of one per AZ
  enable_nat_gateway = true
  single_nat_gateway = true

  tags = local.common_tags
}
