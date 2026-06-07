module "networking" {
  source = "../../modules/aws/networking"

  environment        = "prod"
  vpc_cidr           = "10.2.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

  public_subnet_cidrs  = ["10.2.1.0/24", "10.2.2.0/24", "10.2.3.0/24"]
  private_subnet_cidrs = ["10.2.10.0/24", "10.2.11.0/24", "10.2.12.0/24"]

  # Prod: one NAT gateway per AZ
  # If one AZ's NAT fails, only traffic from that AZ is affected
  enable_nat_gateway = true
  single_nat_gateway = false

  tags = local.common_tags
}

module "security" {
  source = "../../modules/aws/security"

  environment = "prod"
  vpc_id      = module.networking.vpc_id
  vpc_cidr    = module.networking.vpc_cidr

  # Prod: KMS always enabled — customer-managed keys for compliance
  enable_kms = true

  # Prod: restrict bastion to VPN/office IP only
  # Replace with your actual VPN CIDR before applying to real prod
  allowed_ingress_cidrs = ["10.100.0.0/16"]

  tags = local.common_tags
}

module "compute" {
  source = "../../modules/aws/compute"

  environment           = "prod"
  vpc_id                = module.networking.vpc_id
  private_subnet_ids    = module.networking.private_subnet_ids
  public_subnet_ids     = module.networking.public_subnet_ids
  web_sg_id             = module.security.web_sg_id
  app_sg_id             = module.security.app_sg_id
  instance_profile_name = module.security.ec2_instance_profile_name
  kms_key_id            = module.security.kms_key_id

  # Prod: right-sized instances, HA across 3 AZs
  instance_type    = "t3.medium"
  min_size         = 3
  max_size         = 10
  desired_capacity = 3

  tags = local.common_tags
}

module "database" {
  source = "../../modules/aws/database"

  environment        = "prod"
  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids
  database_sg_id     = module.security.database_sg_id
  kms_key_arn        = module.security.kms_key_arn

  # Prod: right-sized DB instance
  instance_class        = "db.t3.medium"
  allocated_storage     = 100
  max_allocated_storage = 500

  # Prod: Multi-AZ mandatory — automatic failover in ~60 seconds
  multi_az = true

  # Prod: 30 days backup retention (compliance requirement)
  backup_retention_days = 30

  # Prod: deletion protection — terraform destroy will fail without disabling this first
  deletion_protection = true

  tags = local.common_tags
}
