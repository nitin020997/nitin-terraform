module "networking" {
  source = "../../modules/aws/networking"

  environment        = "dev"
  vpc_cidr           = "10.0.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b"]

  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = local.common_tags
}

module "security" {
  source = "../../modules/aws/security"

  environment           = "dev"
  vpc_id                = module.networking.vpc_id
  vpc_cidr              = module.networking.vpc_cidr
  enable_kms            = false
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
  instance_type         = "t3.micro"
  min_size              = 1
  max_size              = 2
  desired_capacity      = 1
  kms_key_id            = null

  tags = local.common_tags
}

module "database" {
  source = "../../modules/aws/database"

  environment        = "dev"
  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids
  database_sg_id     = module.security.database_sg_id
  kms_key_arn        = null

  # Dev: smallest instance, no Multi-AZ, short backup retention
  instance_class        = "db.t3.micro"
  allocated_storage     = 20
  max_allocated_storage = 50
  multi_az              = false
  backup_retention_days = 1
  deletion_protection   = false

  tags = local.common_tags
}
