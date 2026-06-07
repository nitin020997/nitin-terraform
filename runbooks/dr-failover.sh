#!/bin/bash
# =============================================================================
# DR Failover Runbook — Active-Passive: Primary (us-east-1) → DR (us-west-2)
#
# Run this when:
#   - Primary region is unhealthy for > 5 minutes
#   - Route53 health checks have already failed over DNS
#   - You need to promote DR database to accept writes
#
# DO NOT run this for transient issues (< 5 min). DNS failover is automatic.
# This script handles the DATABASE layer which requires manual promotion.
#
# Prerequisites:
#   - AWS CLI configured with cross-account access
#   - jq installed
#   - Terraform installed
#   - ENVIRONMENT variable set (prod)
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

log_info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# =============================================================================
# STEP 1: Verify primary is actually down (prevent accidental failover)
# =============================================================================
log_info "STEP 1: Verifying primary region health..."

PRIMARY_HC_ID=$(aws route53 list-health-checks \
  --query "HealthChecks[?Tags[?Key=='Name' && Value=='hc-primary-${ENVIRONMENT}']].Id" \
  --output text 2>/dev/null || echo "")

if [ -z "$PRIMARY_HC_ID" ]; then
  log_warn "Could not find primary health check — proceeding with manual verification"
else
  HC_STATUS=$(aws route53 get-health-check-status \
    --health-check-id "$PRIMARY_HC_ID" \
    --query 'HealthCheckObservations[0].StatusReport.Status' \
    --output text)

  log_info "Primary health check status: $HC_STATUS"

  if [[ "$HC_STATUS" == *"Success"* ]]; then
    log_error "Primary health check is PASSING. Is primary really down?"
    log_error "Run with FORCE=true to override: FORCE=true ./dr-failover.sh"
    [ "${FORCE:-false}" != "true" ] && exit 1
  fi
fi

# =============================================================================
# STEP 2: Check current DNS routing
# =============================================================================
log_info "STEP 2: Checking DNS routing..."

CURRENT_DNS=$(dig +short api.nitin-terraform.com 2>/dev/null | head -1)
log_info "api.nitin-terraform.com currently resolves to: ${CURRENT_DNS:-unknown}"

# =============================================================================
# STEP 3: Check replication lag before promoting DR database
# =============================================================================
log_info "STEP 3: Checking Aurora Global Database replication lag..."

LAG=$(aws rds describe-global-clusters \
  --global-cluster-identifier "$GLOBAL_CLUSTER_ID" \
  --region "$PRIMARY_REGION" \
  --query 'GlobalClusters[0].GlobalClusterMembers[?IsWriter==`false`].GlobalWriteForwardingStatus' \
  --output text 2>/dev/null || echo "unknown")

log_info "Replication lag status: $LAG"

if [[ "$LAG" != *"enabled"* ]] && [ "${FORCE:-false}" != "true" ]; then
  log_warn "Cannot confirm replication status. Data loss risk may be higher."
  read -p "Continue with failover? (yes/no): " CONFIRM
  [ "$CONFIRM" != "yes" ] && exit 1
fi

# =============================================================================
# STEP 4: Promote Aurora secondary to primary
# This is the point of no return — DR becomes the new write region
# =============================================================================
log_info "STEP 4: Promoting Aurora secondary cluster in ${DR_REGION}..."
log_warn "THIS IS THE POINT OF NO RETURN. Any in-flight writes to primary will be lost."

read -p "Type 'PROMOTE' to confirm database promotion: " CONFIRM
[ "$CONFIRM" != "PROMOTE" ] && { log_error "Aborted."; exit 1; }

SECONDARY_CLUSTER_ARN=$(aws rds describe-db-clusters \
  --region "$DR_REGION" \
  --query "DBClusters[?contains(DBClusterIdentifier, 'secondary-${ENVIRONMENT}')].DBClusterArn" \
  --output text)

aws rds failover-global-cluster \
  --global-cluster-identifier "$GLOBAL_CLUSTER_ID" \
  --target-db-cluster-identifier "$SECONDARY_CLUSTER_ARN" \
  --region "$PRIMARY_REGION"

log_info "Promotion initiated. Waiting for DR cluster to become writer..."

# Wait for promotion to complete
for i in {1..30}; do
  STATUS=$(aws rds describe-db-clusters \
    --region "$DR_REGION" \
    --query "DBClusters[?contains(DBClusterIdentifier, 'secondary-${ENVIRONMENT}')].Status" \
    --output text)
  log_info "Cluster status: $STATUS (attempt $i/30)"
  [ "$STATUS" == "available" ] && break
  sleep 10
done

# =============================================================================
# STEP 5: Scale up DR compute (was running at reduced capacity)
# =============================================================================
log_info "STEP 5: Scaling up DR compute in ${DR_REGION}..."

DR_ASG=$(aws autoscaling describe-auto-scaling-groups \
  --region "$DR_REGION" \
  --query "AutoScalingGroups[?contains(AutoScalingGroupName, 'dr')].AutoScalingGroupName" \
  --output text)

if [ -n "$DR_ASG" ]; then
  aws autoscaling update-auto-scaling-group \
    --region "$DR_REGION" \
    --auto-scaling-group-name "$DR_ASG" \
    --min-size 3 \
    --desired-capacity 3

  log_info "DR ASG scaled to min=3, desired=3"
fi

# =============================================================================
# STEP 6: Verify DR is serving traffic
# =============================================================================
log_info "STEP 6: Verifying DR region is healthy..."

DR_ALB=$(aws elbv2 describe-load-balancers \
  --region "$DR_REGION" \
  --query "LoadBalancers[?contains(LoadBalancerName, 'dr')].DNSName" \
  --output text 2>/dev/null || echo "")

if [ -n "$DR_ALB" ]; then
  HTTP_STATUS=$(curl -sk -o /dev/null -w "%{http_code}" "https://${DR_ALB}/health" || echo "000")
  log_info "DR ALB health check response: HTTP $HTTP_STATUS"
  [ "$HTTP_STATUS" != "200" ] && log_warn "DR ALB not returning 200 — investigate before declaring success"
fi

# =============================================================================
# STEP 7: Post-failover actions
# =============================================================================
log_info "STEP 7: Post-failover checklist..."

cat << 'CHECKLIST'
Manual actions required after failover:
  [ ] Notify engineering team (Slack/PagerDuty)
  [ ] Open incident ticket with timeline
  [ ] Confirm all services are pointing to DR database endpoint
  [ ] Update any hardcoded DB endpoints in app config
  [ ] Monitor error rates for 30 minutes
  [ ] Schedule post-mortem within 48 hours
  [ ] Plan failback to primary once primary region recovers
CHECKLIST

log_info "Failover complete. DR region is now primary."
log_info "New write endpoint: $(aws rds describe-db-clusters \
  --region "$DR_REGION" \
  --query "DBClusters[?contains(DBClusterIdentifier, 'secondary-${ENVIRONMENT}')].Endpoint" \
  --output text 2>/dev/null || echo 'check AWS console')"
