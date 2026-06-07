# -----------------------------------------------------------------------------
# AWS Organizations
# This file is applied ONCE from the Management Account
# Never run workloads in the management account — it only manages billing + org
#
# Architect rule: the management account's only job is to hold the org.
# If it gets compromised, attackers can reach every child account.
# Lock it down harder than any other account.
# -----------------------------------------------------------------------------

resource "aws_organizations_organization" "main" {
  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",      # Centralized audit logging
    "config.amazonaws.com",          # Centralized config rules
    "sso.amazonaws.com",             # AWS SSO for human access
    "guardduty.amazonaws.com",       # Centralized threat detection
    "securityhub.amazonaws.com",     # Centralized security findings
    "account.amazonaws.com",         # Account management
  ]

  # ALL_FEATURES enables SCPs — without this, you can't enforce guardrails
  feature_set = "ALL_FEATURES"

  enabled_policy_types = [
    "SERVICE_CONTROL_POLICY",
    "TAG_POLICY",
  ]
}

# -----------------------------------------------------------------------------
# Organizational Units (OUs)
# Group accounts by purpose — policies applied to an OU affect all accounts in it
# -----------------------------------------------------------------------------
resource "aws_organizations_organizational_unit" "security" {
  name      = "Security"
  parent_id = aws_organizations_organization.main.roots[0].id
}

resource "aws_organizations_organizational_unit" "shared_services" {
  name      = "SharedServices"
  parent_id = aws_organizations_organization.main.roots[0].id
}

resource "aws_organizations_organizational_unit" "workloads" {
  name      = "Workloads"
  parent_id = aws_organizations_organization.main.roots[0].id
}

resource "aws_organizations_organizational_unit" "sandboxes" {
  name      = "Sandboxes"
  parent_id = aws_organizations_organization.main.roots[0].id
}

# Workload sub-OUs — separate dev/staging/prod so SCPs can differ
resource "aws_organizations_organizational_unit" "workloads_dev" {
  name      = "Dev"
  parent_id = aws_organizations_organizational_unit.workloads.id
}

resource "aws_organizations_organizational_unit" "workloads_staging" {
  name      = "Staging"
  parent_id = aws_organizations_organizational_unit.workloads.id
}

resource "aws_organizations_organizational_unit" "workloads_prod" {
  name      = "Prod"
  parent_id = aws_organizations_organizational_unit.workloads.id
}

# -----------------------------------------------------------------------------
# Child Accounts
# Each account is isolated — separate billing, separate IAM, separate blast radius
# -----------------------------------------------------------------------------
resource "aws_organizations_account" "security" {
  name      = "nitin-security"
  email     = "aws-security@nitin-terraform.example.com"
  parent_id = aws_organizations_organizational_unit.security.id

  # Never close an account accidentally — requires manual confirmation
  close_on_deletion = false
}

resource "aws_organizations_account" "shared_services" {
  name      = "nitin-shared-services"
  email     = "aws-shared@nitin-terraform.example.com"
  parent_id = aws_organizations_organizational_unit.shared_services.id

  close_on_deletion = false
}

resource "aws_organizations_account" "dev" {
  name      = "nitin-workloads-dev"
  email     = "aws-dev@nitin-terraform.example.com"
  parent_id = aws_organizations_organizational_unit.workloads_dev.id

  close_on_deletion = false
}

resource "aws_organizations_account" "staging" {
  name      = "nitin-workloads-staging"
  email     = "aws-staging@nitin-terraform.example.com"
  parent_id = aws_organizations_organizational_unit.workloads_staging.id

  close_on_deletion = false
}

resource "aws_organizations_account" "prod" {
  name      = "nitin-workloads-prod"
  email     = "aws-prod@nitin-terraform.example.com"
  parent_id = aws_organizations_organizational_unit.workloads_prod.id

  close_on_deletion = false
}

# -----------------------------------------------------------------------------
# Service Control Policies (SCPs)
# SCPs are guardrails — they restrict what even account admins can do
# They are evaluated BEFORE IAM policies — no IAM policy can override an SCP
# Think of SCPs as the org's constitution
# -----------------------------------------------------------------------------

# Deny any action outside approved regions
# Fintech: data residency requirements mean you can't accidentally deploy to eu-west
resource "aws_organizations_policy" "deny_non_approved_regions" {
  name        = "DenyNonApprovedRegions"
  description = "Prevent workloads from being deployed outside approved regions"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyNonApprovedRegions"
        Effect = "Deny"
        NotAction = [
          "iam:*",           # IAM is global — must be exempt
          "organizations:*", # Org actions are global
          "sts:*",           # STS is global
          "cloudfront:*",    # CloudFront is global
          "route53:*",       # Route53 is global
          "support:*",       # Support is global
          "budgets:*",       # Budgets is global
        ]
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "aws:RequestedRegion" = ["us-east-1", "us-west-2"]
          }
        }
      }
    ]
  })
}

# Deny disabling CloudTrail — audit trail must always be on
resource "aws_organizations_policy" "deny_cloudtrail_disable" {
  name        = "DenyCloudTrailDisable"
  description = "Prevent anyone from disabling CloudTrail audit logging"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyCloudTrailDisable"
        Effect = "Deny"
        Action = [
          "cloudtrail:StopLogging",
          "cloudtrail:DeleteTrail",
          "cloudtrail:UpdateTrail",
        ]
        Resource = "*"
      }
    ]
  })
}

# Deny creating root access keys — root should only use console + MFA
resource "aws_organizations_policy" "deny_root_access_keys" {
  name        = "DenyRootAccessKeys"
  description = "Prevent creation of root account access keys"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyRootKeys"
        Effect   = "Deny"
        Action   = ["iam:CreateAccessKey"]
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:PrincipalArn" = ["arn:aws:iam::*:root"]
          }
        }
      }
    ]
  })
}

# Require MFA for sensitive actions in prod
resource "aws_organizations_policy" "require_mfa_prod" {
  name        = "RequireMFAForSensitiveActions"
  description = "Require MFA for destructive actions in prod accounts"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyWithoutMFA"
        Effect = "Deny"
        Action = [
          "ec2:TerminateInstances",
          "rds:DeleteDBInstance",
          "s3:DeleteBucket",
          "iam:DeleteRole",
          "iam:DeletePolicy",
        ]
        Resource = "*"
        Condition = {
          BoolIfExists = {
            "aws:MultiFactorAuthPresent" = "false"
          }
        }
      }
    ]
  })
}

# Attach SCPs to OUs
resource "aws_organizations_policy_attachment" "deny_regions_workloads" {
  policy_id = aws_organizations_policy.deny_non_approved_regions.id
  target_id = aws_organizations_organizational_unit.workloads.id
}

resource "aws_organizations_policy_attachment" "deny_cloudtrail_org" {
  policy_id = aws_organizations_policy.deny_cloudtrail_disable.id
  target_id = aws_organizations_organization.main.roots[0].id
}

resource "aws_organizations_policy_attachment" "deny_root_keys_org" {
  policy_id = aws_organizations_policy.deny_root_access_keys.id
  target_id = aws_organizations_organization.main.roots[0].id
}

resource "aws_organizations_policy_attachment" "require_mfa_prod" {
  policy_id = aws_organizations_policy.require_mfa_prod.id
  target_id = aws_organizations_organizational_unit.workloads_prod.id
}
