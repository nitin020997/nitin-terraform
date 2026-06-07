# -----------------------------------------------------------------------------
# Security Groups
# Rule: one security group per logical role (web, app, db, bastion)
# Never use a single "allow all" SG — blast radius is too large
# -----------------------------------------------------------------------------

# Web tier — accepts HTTPS from internet, HTTP only redirects
resource "aws_security_group" "web" {
  name        = "sg-web-${var.environment}"
  description = "Web tier: accepts HTTPS from internet"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from internet (redirect to HTTPS)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "sg-web-${var.environment}" })
}

# App tier — only accepts traffic from web tier, not directly from internet
resource "aws_security_group" "app" {
  name        = "sg-app-${var.environment}"
  description = "App tier: accepts traffic from web tier only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "From web tier"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "sg-app-${var.environment}" })
}

# Database tier — only accepts traffic from app tier
# Never expose DB to internet or web tier directly
resource "aws_security_group" "database" {
  name        = "sg-db-${var.environment}"
  description = "DB tier: accepts traffic from app tier only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from app tier"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "sg-db-${var.environment}" })
}

# Bastion — restricted SSH access for emergency access only
# In prod, allowed_ingress_cidrs should be your VPN/office IP only
resource "aws_security_group" "bastion" {
  name        = "sg-bastion-${var.environment}"
  description = "Bastion: SSH access restricted to allowed CIDRs"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = length(var.allowed_ingress_cidrs) > 0 ? [1] : []
    content {
      description = "SSH from allowed CIDRs"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.allowed_ingress_cidrs
    }
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "sg-bastion-${var.environment}" })
}

# -----------------------------------------------------------------------------
# IAM Roles
# -----------------------------------------------------------------------------

# EC2 instance role — allows EC2 to call AWS APIs (SSM, CloudWatch, S3)
# Using IAM roles instead of access keys on instances is non-negotiable
resource "aws_iam_role" "ec2_instance" {
  name = "role-ec2-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = merge(var.tags, { Name = "role-ec2-${var.environment}" })
}

# Attach AWS managed policies — least privilege
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.ec2_instance.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Instance profile — wrapper that lets EC2 use the IAM role
resource "aws_iam_instance_profile" "ec2" {
  name = "profile-ec2-${var.environment}"
  role = aws_iam_role.ec2_instance.name

  tags = merge(var.tags, { Name = "profile-ec2-${var.environment}" })
}

# -----------------------------------------------------------------------------
# KMS Keys — encryption at rest for all sensitive data
# Fintech requirement: all data encrypted with customer-managed keys
# -----------------------------------------------------------------------------

resource "aws_kms_key" "main" {
  count = var.enable_kms ? 1 : 0

  description             = "KMS key for ${var.environment} environment"
  deletion_window_in_days = var.environment == "prod" ? 30 : 7
  enable_key_rotation     = true

  tags = merge(var.tags, { Name = "kms-${var.environment}" })
}

resource "aws_kms_alias" "main" {
  count = var.enable_kms ? 1 : 0

  name          = "alias/nitin-terraform-${var.environment}"
  target_key_id = aws_kms_key.main[0].key_id
}
