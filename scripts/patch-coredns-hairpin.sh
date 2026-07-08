#!/bin/bash
set -e
# ============================================
# Patches CoreDNS so in-cluster pods resolve the
# public domain to ingress-nginx's internal ClusterIP.
# Fixes AWS's VPC hairpin-NAT limitation, which otherwise
# makes cert-manager's ACME HTTP-01 self-check time out.
#
# IMPORTANT: k3s's default Corefile already has ONE `hosts` plugin
# block (hosts /etc/coredns/NodeHosts {...}). CoreDNS only allows a
# single `hosts` plugin per server block, so we MERGE our entry into
# that existing block rather than adding a second one.
#
# Idempotent: safe to re-run on every deploy.
# ============================================

DOMAIN=${1:?Usage: $0 <domain> [ingress-namespace] [ingress-svc-name]}
INGRESS_NAMESPACE=${2:-ingress-nginx}
INGRESS_SVC=${3:-ingress-nginx-controller}

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

# --- Ensure jq is available (install if missing, e.g. when run directly on a node) ---
if ! command -v jq >/dev/null 2>&1; then
  echo -e "${YELLOW}⚠️  jq not found — attempting to install...${NC}"
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -qq && sudo apt-get install -y -qq jq
  elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y -q jq
  else
    echo -e "${RED}❌ Could not auto-install jq (no apt-get/yum found). Install it manually.${NC}"
    exit 1
  fi
fi

echo -e "${YELLOW}🔎 Looking up ClusterIP for $INGRESS_SVC in $INGRESS_NAMESPACE...${NC}"
CLUSTER_IP=$(kubectl -n "$INGRESS_NAMESPACE" get svc "$INGRESS_SVC" -o jsonpath='{.spec.clusterIP}' 2>/dev/null || true)

if [ -z "$CLUSTER_IP" ] || [ "$CLUSTER_IP" = "None" ]; then
  echo -e "${RED}❌ Could not determine ClusterIP for $INGRESS_SVC. Is ingress-nginx installed?${NC}"
  exit 1
fi

echo -e "${GREEN}✅ Found ClusterIP: $CLUSTER_IP${NC}"
echo -e "${YELLOW}🔧 Patching CoreDNS: $DOMAIN -> $CLUSTER_IP${NC}"

CURRENT=$(kubectl -n kube-system get configmap coredns -o jsonpath='{.data.Corefile}')

# Strip any previously-injected marker line (idempotent re-run) —
# only removes our single injected line between the markers, leaving
# the existing `hosts /etc/coredns/NodeHosts { ... }` block untouched.
STRIPPED=$(echo "$CURRENT" | awk '
  /# BEGIN taskapp-hairpin-fix/{skip=1; next}
  /# END taskapp-hairpin-fix/{skip=0; next}
  skip==1{next}
  {print}
')

# Merge our entry into the EXISTING hosts plugin invocation line
# (matches "hosts /etc/coredns/NodeHosts {" or similar), rather than
# creating a second hosts{} block, which CoreDNS rejects outright.
NEW_COREFILE=$(echo "$STRIPPED" | awk -v ip="$CLUSTER_IP" -v domain="$DOMAIN" '
  /^[ \t]*hosts[ \t].*\{[ \t]*$/ && !done {
    print
    print "      # BEGIN taskapp-hairpin-fix"
    print "      " ip " " domain
    print "      # END taskapp-hairpin-fix"
    done=1
    next
  }
  { print }
')

MARKER_COUNT=$(echo "$NEW_COREFILE" | grep -c "BEGIN taskapp-hairpin-fix" || true)
HOSTS_BLOCK_COUNT=$(echo "$NEW_COREFILE" | grep -c "^[ \t]*hosts[ \t].*{" || true)

if [ "$MARKER_COUNT" -ne 1 ]; then
  echo -e "${RED}❌ Failed to safely inject host entry — anchor line not found or matched multiple times. Aborting without applying.${NC}"
  echo "$NEW_COREFILE"
  exit 1
fi

if [ "$HOSTS_BLOCK_COUNT" -gt 1 ]; then
  echo -e "${RED}❌ Refusing to apply — resulting Corefile would have more than one 'hosts' block (CoreDNS forbids this).${NC}"
  exit 1
fi

kubectl -n kube-system get configmap coredns -o json \
  | jq --arg corefile "$NEW_COREFILE" '.data.Corefile = $corefile' \
  | kubectl apply -f -

echo -e "${YELLOW}🔄 Restarting CoreDNS to pick up the change...${NC}"
kubectl -n kube-system rollout restart deployment coredns

echo -e "${YELLOW}⏳ Waiting for CoreDNS rollout (best-effort, non-fatal)...${NC}"
if ! kubectl -n kube-system rollout status deployment coredns --timeout=120s; then
  echo -e "${RED}⚠️  CoreDNS rollout did not complete in time. Config was applied — check pod status manually:${NC}"
  echo "    kubectl -n kube-system get pods -l k8s-app=kube-dns"
  echo "    kubectl -n kube-system logs -l k8s-app=kube-dns --tail=50"
  exit 0
fi

echo -e "${GREEN}✅ CoreDNS patched and rolled out successfully: $DOMAIN -> $CLUSTER_IP${NC}"
