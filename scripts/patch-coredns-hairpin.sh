#!/bin/bash
set -e
# ============================================
# Patches CoreDNS so in-cluster pods resolve the
# public domain to ingress-nginx's internal ClusterIP.
# Fixes AWS's VPC hairpin-NAT limitation, which otherwise
# makes cert-manager's ACME HTTP-01 self-check time out.
# Idempotent: safe to re-run on every deploy.
# ============================================

DOMAIN=${1:?Usage: $0 <domain> [ingress-namespace] [ingress-svc-name]}
INGRESS_NAMESPACE=${2:-ingress-nginx}
INGRESS_SVC=${3:-ingress-nginx-controller}

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

command -v jq >/dev/null 2>&1 || { echo -e "${RED}❌ jq is required (already installed via setup-ci-deps)${NC}"; exit 1; }

echo -e "${YELLOW}🔎 Looking up ClusterIP for $INGRESS_SVC in $INGRESS_NAMESPACE...${NC}"
CLUSTER_IP=$(kubectl -n "$INGRESS_NAMESPACE" get svc "$INGRESS_SVC" -o jsonpath='{.spec.clusterIP}' 2>/dev/null || true)

if [ -z "$CLUSTER_IP" ] || [ "$CLUSTER_IP" = "None" ]; then
  echo -e "${RED}❌ Could not determine ClusterIP for $INGRESS_SVC. Is ingress-nginx installed?${NC}"
  exit 1
fi

echo -e "${GREEN}✅ Found ClusterIP: $CLUSTER_IP${NC}"
echo -e "${YELLOW}🔧 Patching CoreDNS: $DOMAIN -> $CLUSTER_IP${NC}"

CURRENT=$(kubectl -n kube-system get configmap coredns -o jsonpath='{.data.Corefile}')

# Strip any previously-injected block (idempotent re-run)
STRIPPED=$(echo "$CURRENT" | awk '
  /# BEGIN taskapp-hairpin-fix/{skip=1}
  /# END taskapp-hairpin-fix/{skip=0; next}
  skip==1{next}
  {print}
')

# Re-inject a fresh block right after the first "servers-block open" line
NEW_COREFILE=$(echo "$STRIPPED" | awk -v ip="$CLUSTER_IP" -v domain="$DOMAIN" '
  /^\.:53 \{/ && !done {
    print
    print "    # BEGIN taskapp-hairpin-fix"
    print "    hosts {"
    print "        " ip " " domain
    print "        fallthrough"
    print "    }"
    print "    # END taskapp-hairpin-fix"
    done=1
    next
  }
  { print }
')

# Preserve every other key in the ConfigMap (e.g. NodeHosts) — only replace Corefile
kubectl -n kube-system get configmap coredns -o json \
  | jq --arg corefile "$NEW_COREFILE" '.data.Corefile = $corefile' \
  | kubectl apply -f -

echo -e "${YELLOW}🔄 Restarting CoreDNS to pick up the change...${NC}"
kubectl -n kube-system rollout restart deployment coredns
kubectl -n kube-system rollout status deployment coredns --timeout=60s

echo -e "${GREEN}✅ CoreDNS patched: $DOMAIN now resolves in-cluster to $CLUSTER_IP${NC}"
