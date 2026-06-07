# -----------------------------------------------------------------------------
# DB Subnet Group
# Tells RDS which subnets it can place instances in
# Must span at least 2 AZs — even for single-AZ deployments
# This allows future Multi-AZ promotion without recreation
# -----------------------------------------------------------------------------
resource "aws_db_subnet_group" "main" {
  name       = "dbsubnet-${var.environment}"
  subnet_ids = var.private_subnet_ids

  tags = merge(var.tags, { Name = "dbsubnet-${var.environment}" })
}

# -----------------------------------------------------------------------------
# DB Parameter Group
# Controls PostgreSQL runtime settings
# Using a custom parameter group (not default) means you can tune settings
# without recreating the RDS instance
# -----------------------------------------------------------------------------
resource "aws_db_parameter_group" "main" {
  name   = "dbpg-postgres15-${var.environment}"
  family = "postgres15"

  # Force SSL connections — non-negotiable for fintech
  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  # Log slow queries > 1 second for performance analysis
  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  # Log all connections for audit trail
  parameter {
    name  = "log_connections"
    value = "1"
  }

  tags = merge(var.tags, { Name = "dbpg-${var.environment}" })

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# Random password for the DB master user
# Never hardcode DB passwords or put them in tfvars files
# Store in AWS Secrets Manager, retrieve via data source when needed
# -----------------------------------------------------------------------------
resource "random_password" "db" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db_password" {
  name       = "/${var.environment}/database/master-password"
  kms_key_id = var.kms_key_arn

  tags = merge(var.tags, { Name = "secret-db-${var.environment}" })
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db.result
    endpoint = aws_db_instance.main.endpoint
    dbname   = var.db_name
  })
}

# -----------------------------------------------------------------------------
# RDS Instance
# -----------------------------------------------------------------------------
resource "aws_db_instance" "main" {
  identifier = "rds-${var.environment}"

  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.database_sg_id]
  parameter_group_name   = aws_db_parameter_group.main.name

  # Storage
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn

  # High Availability — prod must have this enabled
  multi_az = var.multi_az

  # Backups
  backup_retention_period = var.backup_retention_days
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"
  copy_tags_to_snapshot   = true

  # Security
  publicly_accessible = false
  deletion_protection = var.deletion_protection

  # Performance Insights for query-level monitoring
  performance_insights_enabled          = true
  performance_insights_retention_period = var.environment == "prod" ? 731 : 7

  # Don't take a final snapshot in dev (saves cost/clutter)
  # Always take final snapshot in prod
  skip_final_snapshot       = var.environment != "prod"
  final_snapshot_identifier = var.environment == "prod" ? "rds-${var.environment}-final-${formatdate("YYYYMMDD", timestamp())}" : null

  tags = merge(var.tags, { Name = "rds-${var.environment}" })
}
