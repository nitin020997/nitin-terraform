#!/bin/bash
# =============================================================================
# DR Failback Runbook — After primary region recovers, return traffic to us-east-1
#
# Run this ONLY after:
#   1. Primary region is fully healthy
#   2. DR has been running as primary for at least 30 minutes (data settled)
#   3. Incident has been declared resolved
#   4. Engineering team has approved failback
# =============================================================================

set -euo pipefail

ENVIRONMENT=${ENVIRONMENT:-prod}
PRIMARY_REGION="us-east-1"
DR_REGION="us-west-2"
GLOBAL_CLUSTER_ID="global-${ENVIRONMENT}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

log_warn "DR FAILBACK — This will return write traffic to ${PRIMARY_REGION}"
log_warn "Ensure primary region is fully healthy before proceeding."
read -p "Confirm primary region is healthy and team has approved? (yes/no): " CONFIRM
[ "$CONFIRM" != "yes" ] && exit 1

# Promote primary cluster back to writer
log_info "Re-adding primary region to global cluster and promoting..."

PRIMARY_CLUSTER_ARN=$(aws rds describe-db-clusters \
  --region "$PRIMARY_REGION" \
  --query "DBClusters[?contains(DBClusterIdentifier, 'primary-${ENVIRONMENT}')].DBClusterArn" \
  --output text)

aws rds failover-global-cluster \
  --global-cluster-identifier "$GLOBAL_CLUSTER_ID" \
  --target-db-cluster-identifier "$PRIMARY_CLUSTER_ARN" \
  --region "$DR_REGION"

log_info "Failback initiated. Monitor replication lag before scaling down DR."

# Scale DR back to standby capacity
log_info "Scaling DR compute back to standby capacity..."

DR_ASG=$(aws autoscaling describe-auto-scaling-groups \
  --region "$DR_REGION" \
  --query "AutoScalingGroups[?contains(AutoScalingGroupName, 'dr')].AutoScalingGroupName" \
  --output text)

if [ -n "$DR_ASG" ]; then
  aws autoscaling update-auto-scaling-group \
    --region "$DR_REGION" \
    --auto-scaling-group-name "$DR_ASG" \
    --min-size 1 \
    --desired-capacity 1

  log_info "DR ASG scaled back to standby (min=1, desired=1)"
fi

log_info "Failback complete. Primary region ${PRIMARY_REGION} is now writer."
log_info "Schedule a DR drill within 30 days to verify the full process works end-to-end."
