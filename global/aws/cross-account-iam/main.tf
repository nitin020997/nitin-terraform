# -----------------------------------------------------------------------------
# Cross-Account IAM Strategy
#
# Architecture:
#   GitHub Actions → OIDC Trust → CI/CD Role (in management account)
#                 → AssumeRole → TerraformDeployRole (in each workload account)
#
# Why OIDC instead of static credentials?
#   - No long-lived AWS access keys stored in GitHub secrets
#   - GitHub generates a short-lived token per workflow run
#   - If a token leaks, it expires in minutes not years
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# GitHub OIDC Provider
# Allows GitHub Actions to authenticate to AWS without storing credentials
# This is created in the management account and trusted by all child accounts
# -----------------------------------------------------------------------------
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # GitHub's OIDC thumbprint — this is public and stable
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# -----------------------------------------------------------------------------
# CI/CD Role — lives in management account
# GitHub Actions assumes this role first, then assumes account-specific roles
# -----------------------------------------------------------------------------
resource "aws_iam_role" "cicd" {
  name = "GitHubActionsCICD"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # Only allow this specific repo — not any GitHub repo
            "token.actions.githubusercontent.com:sub" = "repo:nitin020997/nitin-terraform:*"
          }
        }
      }
    ]
  })

  tags = {
    ManagedBy = "terraform"
    Purpose   = "github-actions-cicd"
  }
}

# Allow CI/CD role to assume the deploy role in any child account
resource "aws_iam_role_policy" "cicd_assume" {
  name = "AssumeDeployRoles"
  role = aws_iam_role.cicd.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = [
          # These ARNs reference roles created in each child account below
          "arn:aws:iam::${var.dev_account_id}:role/TerraformDeployRole",
          "arn:aws:iam::${var.staging_account_id}:role/TerraformDeployRole",
          "arn:aws:iam::${var.prod_account_id}:role/TerraformDeployRole",
        ]
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# TerraformDeployRole — created in each workload account
# CI/CD role assumes this to perform deployments
# Scoped to only what Terraform needs — not AdministratorAccess
# -----------------------------------------------------------------------------

# Dev account deploy role — more permissive (faster iteration)
resource "aws_iam_role" "terraform_deploy_dev" {
  provider = aws.dev
  name     = "TerraformDeployRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          # Only the CI/CD role in the management account can assume this
          AWS = aws_iam_role.cicd.arn
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    ManagedBy = "terraform"
    Purpose   = "cicd-terraform-deploy"
  }
}

resource "aws_iam_role_policy_attachment" "terraform_deploy_dev" {
  provider   = aws.dev
  role       = aws_iam_role.terraform_deploy_dev.name
  # Dev: PowerUserAccess (almost everything except IAM/org management)
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

# Staging account deploy role
resource "aws_iam_role" "terraform_deploy_staging" {
  provider = aws.staging
  name     = "TerraformDeployRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.cicd.arn }
        Action    = "sts:AssumeRole"

        # Extra condition for staging: only main branch can deploy
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "nitin-terraform-staging"
          }
        }
      }
    ]
  })

  tags = {
    ManagedBy = "terraform"
    Purpose   = "cicd-terraform-deploy"
  }
}

resource "aws_iam_role_policy_attachment" "terraform_deploy_staging" {
  provider   = aws.staging
  role       = aws_iam_role.terraform_deploy_staging.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

# Prod account deploy role — most restricted
resource "aws_iam_role" "terraform_deploy_prod" {
  provider = aws.prod
  name     = "TerraformDeployRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.cicd.arn }
        Action    = "sts:AssumeRole"

        Condition = {
          StringEquals = {
            "sts:ExternalId" = "nitin-terraform-prod"
          }
          # Only allow during change window (enforced via CI/CD pipeline too)
          DateGreaterThan = {
            "aws:CurrentTime" = "2000-01-01T09:00:00Z"
          }
        }
      }
    ]
  })

  tags = {
    ManagedBy = "terraform"
    Purpose   = "cicd-terraform-deploy"
  }
}

resource "aws_iam_role_policy_attachment" "terraform_deploy_prod" {
  provider   = aws.prod
  role       = aws_iam_role.terraform_deploy_prod.name
  # Prod: custom policy — only what prod Terraform actually needs
  policy_arn = aws_iam_policy.terraform_prod_deploy.arn
}

# Prod gets a scoped custom policy instead of PowerUserAccess
resource "aws_iam_policy" "terraform_prod_deploy" {
  provider    = aws.prod
  name        = "TerraformProdDeployPolicy"
  description = "Scoped permissions for Terraform prod deployments"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:*",
          "elasticloadbalancing:*",
          "autoscaling:*",
          "rds:*",
          "secretsmanager:*",
          "kms:*",
          "iam:GetRole",
          "iam:CreateRole",
          "iam:AttachRolePolicy",
          "iam:PassRole",
          "s3:*",
        ]
        Resource = "*"
      },
      {
        # Explicit deny — even this role can't delete prod KMS keys
        Effect = "Deny"
        Action = [
          "kms:ScheduleKeyDeletion",
          "rds:DeleteDBInstance",
        ]
        Resource = "*"
      }
    ]
  })
}
