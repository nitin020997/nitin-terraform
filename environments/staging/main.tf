module "networking" {
  source = "../../modules/aws/networking"

  environment        = "staging"
  vpc_cidr           = "10.1.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

  public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
  private_subnet_cidrs = ["10.1.10.0/24", "10.1.11.0/24", "10.1.12.0/24"]

  # Staging: mirrors prod — one NAT per AZ for HA testing
  enable_nat_gateway = true
  single_nat_gateway = false

  tags = local.common_tags
}

module "security" {
  source = "../../modules/aws/security"

  environment = "staging"
  vpc_id      = module.networking.vpc_id
  vpc_cidr    = module.networking.vpc_cidr

  # Staging: KMS enabled (mirrors prod — catches KMS permission issues before prod)
  enable_kms = true

  # Staging: restrict bastion to known CIDRs only
  allowed_ingress_cidrs = ["10.0.0.0/8"]

  tags = local.common_tags
}

module "compute" {
  source = "../../modules/aws/compute"

  environment           = "staging"
  vpc_id                = module.networking.vpc_id
  private_subnet_ids    = module.networking.private_subnet_ids
  public_subnet_ids     = module.networking.public_subnet_ids
  web_sg_id             = module.security.web_sg_id
  app_sg_id             = module.security.app_sg_id
  instance_profile_name = module.security.ec2_instance_profile_name

  # Staging: prod-like sizing to catch resource issues early
  instance_type    = "t3.small"
  min_size         = 2
  max_size         = 4
  desired_capacity = 2

  kms_key_id = module.security.kms_key_id

  tags = local.common_tags
}
