# Changelog

All notable changes to this module library are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.0.0] - 2026-06-07

### Added
**Phase 1 — Fintech Startup Foundation**

#### modules/aws/networking
- VPC with configurable CIDR
- Public and private subnets across multiple AZs
- Internet Gateway, NAT Gateways (single or per-AZ)
- Route tables with proper associations

#### modules/aws/security
- Tiered security groups: web / app / database / bastion
- IAM role for EC2 with SSM + CloudWatch (no access keys)
- KMS key with automatic rotation, configurable per environment

#### modules/aws/compute
- Launch template with IMDSv2 enforced, encrypted EBS (gp3)
- Application Load Balancer with HTTP→HTTPS redirect
- Auto Scaling Group with rolling instance refresh
- CPU target tracking scaling policy

#### modules/aws/database
- RDS PostgreSQL with custom parameter group (SSL forced, slow query logging)
- Automated password via random_password → Secrets Manager
- Multi-AZ, storage autoscaling, Performance Insights
- Deletion protection + final snapshot on prod

#### modules/azure/networking
- Virtual Network + public/private subnets
- Network Security Groups attached at subnet level
- Azure NAT Gateway for private subnet outbound traffic

#### modules/gcp/networking
- Global VPC with regional subnet
- Secondary IP ranges for future GKE (pods + services)
- Cloud Router + Cloud NAT
- IAP SSH firewall rule (no port 22 to internet)
- VPC Flow Logs

#### modules/oci/networking
- VCN + IGW + NAT Gateway + Service Gateway
- Security Lists at subnet level
- prohibit_public_ip_on_vnic on private subnets

**Phase 2 — Enterprise Scale**

#### global/aws/organizations
- AWS Organizations with OU hierarchy
- SCPs: region restriction, CloudTrail protection, root key deny, MFA for prod

#### global/aws/cross-account-iam
- GitHub OIDC provider (no static credentials)
- Cross-account assume role chain: GitHub → CI/CD role → account deploy role
- Scoped prod deploy policy (explicit deny on KMS delete + RDS delete)

### Breaking Changes
None (initial release)

---

## How to upgrade

### Consuming a specific version
```hcl
module "networking" {
  source = "git::https://github.com/nitin020997/nitin-terraform.git//modules/aws/networking?ref=v1.0.0"
}
```

### Upgrading to a new version
1. Check this CHANGELOG for breaking changes
2. Update the `ref` in your module source
3. Run `terraform init -upgrade`
4. Run `terraform plan` and review changes
5. Apply in dev first, then staging, then prod
