module "networking" {
  source = "../../modules/aws/networking"

  environment        = "dev"
  vpc_cidr           = "10.0.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b"]

  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]

  # Dev: single NAT gateway (saves ~$32/month vs one per AZ)
  enable_nat_gateway = true
  single_nat_gateway = true

  tags = local.common_tags
}

module "security" {
  source = "../../modules/aws/security"

  environment = "dev"
  vpc_id      = module.networking.vpc_id
  vpc_cidr    = module.networking.vpc_cidr

  # Dev: disable KMS to save cost (use AWS managed keys instead)
  enable_kms = false

  # Dev: no IP restriction on bastion (prod should lock this to VPN IP)
  allowed_ingress_cidrs = ["0.0.0.0/0"]

  tags = local.common_tags
}

module "compute" {
  source = "../../modules/aws/compute"

  environment           = "dev"
  vpc_id                = module.networking.vpc_id
  private_subnet_ids    = module.networking.private_subnet_ids
  public_subnet_ids     = module.networking.public_subnet_ids
  web_sg_id             = module.security.web_sg_id
  app_sg_id             = module.security.app_sg_id
  instance_profile_name = module.security.ec2_instance_profile_name

  # Dev: smallest instance, min 1 max 2
  instance_type    = "t3.micro"
  min_size         = 1
  max_size         = 2
  desired_capacity = 1

  # Dev: no KMS key (disabled above)
  kms_key_id = null

  tags = local.common_tags
}
