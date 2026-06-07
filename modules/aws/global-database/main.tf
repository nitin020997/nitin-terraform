# -----------------------------------------------------------------------------
# RDS Global Database
#
# Architecture:
#   Primary cluster (us-east-1) → async replication → Secondary cluster (us-west-2)
#
# Why Global Database instead of cross-region read replica?
# - Global Database replication lag: typically < 1 second (uses dedicated replication infra)
# - Cross-region read replica lag: 1-30 seconds (replicates via binlog over internet)
# - Global Database failover: ~1 minute (secondary promotes to primary automatically)
# - Read replica failover: manual + application reconfiguration required
#
# Fintech requirement: < 1 second replication lag means financial data is
# nearly synchronized at the DR region before a failover is needed.
# -----------------------------------------------------------------------------

# Global cluster — the umbrella that spans both regions
resource "aws_rds_global_cluster" "main" {
  global_cluster_identifier = "global-${var.environment}"
  engine                    = "aurora-postgresql"
  engine_version            = "15.4"
  database_name             = "appdb"
  storage_encrypted         = true

  # Deletion protection — prevents accidental global cluster removal
  deletion_protection = var.environment == "prod"
}

# Primary cluster — us-east-1, serves all writes
resource "aws_rds_cluster" "primary" {
  cluster_identifier        = "aurora-primary-${var.environment}"
  global_cluster_identifier = aws_rds_global_cluster.main.id
  engine                    = aws_rds_global_cluster.main.engine
  engine_version            = aws_rds_global_cluster.main.engine_version

  db_subnet_group_name   = "${var.environment}-db-subnet"
  vpc_security_group_ids = [var.dr_security_group_id]

  kms_key_id        = var.dr_kms_key_arn
  storage_encrypted = true

  backup_retention_period = 30
  preferred_backup_window = "03:00-04:00"
  skip_final_snapshot     = false
  final_snapshot_identifier = "aurora-primary-${var.environment}-final"

  deletion_protection = var.environment == "prod"

  tags = merge(var.tags, {
    Name   = "aurora-primary-${var.environment}"
    Role   = "primary-writer"
    Region = "us-east-1"
  })
}

resource "aws_rds_cluster_instance" "primary" {
  count = var.environment == "prod" ? 2 : 1

  identifier         = "aurora-primary-${var.environment}-${count.index}"
  cluster_identifier = aws_rds_cluster.primary.id
  instance_class     = var.dr_instance_class
  engine             = aws_rds_cluster.primary.engine
  engine_version     = aws_rds_cluster.primary.engine_version

  performance_insights_enabled          = true
  performance_insights_retention_period = var.environment == "prod" ? 731 : 7

  tags = merge(var.tags, { Name = "aurora-primary-${var.environment}-${count.index}" })
}

# Secondary cluster — us-west-2, read-only until failover
resource "aws_rds_cluster" "secondary" {
  provider = aws.dr

  cluster_identifier        = "aurora-secondary-${var.environment}"
  global_cluster_identifier = aws_rds_global_cluster.main.id
  engine                    = aws_rds_global_cluster.main.engine
  engine_version            = aws_rds_global_cluster.main.engine_version

  db_subnet_group_name   = var.dr_subnet_group_name
  vpc_security_group_ids = [var.dr_security_group_id]

  kms_key_id        = var.dr_kms_key_arn
  storage_encrypted = true

  # Secondary clusters in a global DB do not take independent backups
  skip_final_snapshot = true

  # Secondary cannot have deletion protection — primary controls lifecycle
  deletion_protection = false

  tags = merge(var.tags, {
    Name   = "aurora-secondary-${var.environment}"
    Role   = "dr-reader"
    Region = "us-west-2"
  })

  depends_on = [aws_rds_cluster_instance.primary]
}

resource "aws_rds_cluster_instance" "secondary" {
  provider = aws.dr

  identifier         = "aurora-secondary-${var.environment}-0"
  cluster_identifier = aws_rds_cluster.secondary.id
  instance_class     = var.dr_instance_class
  engine             = aws_rds_cluster.secondary.engine
  engine_version     = aws_rds_cluster.secondary.engine_version

  # DR instance is smaller — scales up during failover if needed
  tags = merge(var.tags, { Name = "aurora-secondary-${var.environment}-0" })
}
