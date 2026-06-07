# nitin-terraform

Production-grade multi-cloud Terraform platform built from scratch.

## Architecture

This platform evolves through three phases mirroring real-world org growth:

| Phase | Scenario | Clouds | Key Concepts |
|-------|----------|--------|-------------|
| 1 | Fintech Startup | AWS | Module design, state strategy, workspace isolation |
| 2 | Enterprise Scale | AWS + Azure | Multi-account, team boundaries, blast radius control |
| 3 | Global SaaS | AWS + Azure + GCP + OCI | Multi-region HA, DR, cost attribution |

## Folder Structure

```
nitin-terraform/
├── modules/          # Reusable modules per cloud (no env-specific config)
│   ├── aws/
│   ├── azure/
│   ├── gcp/
│   └── oci/
├── environments/     # Modules composed per environment (isolated state)
│   ├── dev/
│   ├── staging/
│   └── prod/
├── global/           # Shared infra per cloud (DNS, IAM, state backend)
│   ├── aws/
│   ├── azure/
│   ├── gcp/
│   └── oci/
├── scripts/          # LocalStack setup, bootstrap helpers
└── .github/          # CI/CD workflows
```

## Key Architectural Decisions

### State Isolation
Each environment (dev/staging/prod) has its own Terraform state file stored in a dedicated backend bucket. This ensures a `terraform destroy` in dev cannot affect prod.

### Module Versioning
Modules are versioned via git tags. Environments pin to a specific module version — no implicit latest.

### Blast Radius Control
- Dev: auto-apply on merge
- Staging: plan on PR, apply requires approval
- Prod: plan on PR, apply requires 2 approvals + change window

### Multi-Cloud Compatibility
Each cloud has identical module categories (networking, compute, database, security). The interface (inputs/outputs) is consistent across clouds where possible.

## Local Development

Uses LocalStack (AWS), Azurite (Azure), GCP emulator, and OCI emulator. No real cloud accounts needed.

### Prerequisites
```bash
brew install terraform
brew install awscli
pip install localstack
brew install --cask docker
```

### Start LocalStack
```bash
./scripts/localstack-start.sh
```

## Environments

### Dev
- Auto-applies on merge to main
- Smallest instance sizes
- No deletion protection

### Staging
- Mirrors prod configuration
- Requires PR approval to apply
- Deletion protection enabled

### Prod
- Requires 2 approvals
- Change window enforcement
- Full deletion protection
- Audit logging enabled
