# Phase 2 — Enterprise Scale Architecture

## Multi-Account Strategy

### Why multiple accounts?
A single AWS account is a single blast radius. If someone runs `terraform destroy` with broad permissions, they can wipe everything. Accounts are the strongest isolation boundary in AWS.

### Account Structure (Landing Zone pattern)

```
AWS Organization (Root)
├── Management Account      — billing, org-level SCPs only. NO workloads here.
├── Security Account        — centralized CloudTrail, GuardDuty, Security Hub
├── Shared Services Account — shared infra: VPN, DNS, artifact registries
├── Workloads
│   ├── Dev Account         — all dev workloads
│   ├── Staging Account     — all staging workloads
│   └── Prod Account        — all prod workloads
└── Sandbox Accounts        — per-engineer throwaway environments
```

### Key decisions:
1. **SCPs (Service Control Policies)** — applied at org level. No account can override them.
   - Deny all actions outside approved regions
   - Deny disabling CloudTrail
   - Deny creating root access keys
2. **Cross-account IAM** — CI/CD pipeline assumes a role in each account rather than having per-account credentials
3. **Shared VPC peering** — Shared Services VPC peers with Dev/Staging/Prod for internal connectivity

## Module Versioning Strategy

### Problem
If two teams use the same module and one team updates it, the other team's infrastructure breaks unexpectedly.

### Solution: Git tags as module versions

```hcl
# Pinned to a specific version — safe, predictable
module "networking" {
  source = "git::https://github.com/nitin020997/nitin-terraform.git//modules/aws/networking?ref=v1.2.0"
}

# Latest — only acceptable in dev
module "networking" {
  source = "git::https://github.com/nitin020997/nitin-terraform.git//modules/aws/networking?ref=main"
}
```

### Versioning convention (SemVer)
- `v1.0.0` → breaking change (rename a variable, remove an output)
- `v1.1.0` → new feature (add optional variable with a default)
- `v1.1.1` → bug fix (fix a resource configuration)

### Release process
1. PR merged to main
2. GitHub Action runs `terraform validate` on all modules
3. Tag created: `git tag v1.x.x && git push --tags`
4. CHANGELOG updated
5. Teams notified — they choose when to upgrade

## Blast Radius Control

### State partitioning
Each team owns their state files. Platform team cannot accidentally destroy app team's infra.

```
State files:
  nitin-terraform-dev-networking     # networking team
  nitin-terraform-dev-compute        # compute team  
  nitin-terraform-dev-database       # database team
  nitin-terraform-prod-networking
  nitin-terraform-prod-compute
  nitin-terraform-prod-database
```

### Remote state data sources
Teams read each other's outputs without sharing state:

```hcl
# Compute team reads networking team's outputs
data "terraform_remote_state" "networking" {
  backend = "remote"
  config = {
    organization = "nitin-terraform"
    workspaces = {
      name = "nitin-terraform-${var.environment}-networking"
    }
  }
}

# Use it
subnet_ids = data.terraform_remote_state.networking.outputs.private_subnet_ids
```

## What Phase 2 will build
- [ ] AWS Organizations + account structure (simulated locally)
- [ ] Cross-account IAM roles for CI/CD
- [ ] Module versioning with git tags + CHANGELOG
- [ ] State file partitioning per team
- [ ] Remote state data sources between teams
- [ ] Azure subscription structure (mirrors AWS account structure)
- [ ] VNet peering between Azure environments
