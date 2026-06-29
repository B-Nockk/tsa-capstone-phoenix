#!/bin/bash
set -e

# ============================================
# Secrets Setup Script
# Generates, encrypts, and injects secrets
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Environment
ENV=${1:-dev}
SECRETS_DIR="$ROOT_DIR/.secrets"
ENV_FILE="$SECRETS_DIR/$ENV.env"
SEALED_NAMESPACE="sealed-secrets"

echo -e "${GREEN}🔐 Secrets Setup for $ENV environment${NC}"

# ============================================
# 1. Load or Generate Secrets
# ============================================

mkdir -p "$SECRETS_DIR"

if [ -f "$ENV_FILE" ]; then
    echo -e "${YELLOW}⚠️  Secrets file exists: $ENV_FILE${NC}"
    echo -e "${YELLOW}Using existing secrets...${NC}"
    source "$ENV_FILE"
else
    echo -e "${YELLOW}📝 Generating new secrets for $ENV...${NC}"

    # Generate random passwords
    POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d '\n')
    SECRET_KEY=$(openssl rand -base64 32 | tr -d '\n')

    # Write to file
    cat > "$ENV_FILE" << EOF
# Auto-generated secrets for $ENV
# Generated on: $(date)

POSTGRES_PASSWORD=$POSTGRES_PASSWORD
SECRET_KEY=$SECRET_KEY

# CI/CD secrets (must be set manually or via GH CLI)
GHCR_PAT=${GHCR_PAT:-CHANGE_ME}
GITHUB_TOKEN=${GITHUB_TOKEN:-CHANGE_ME}

# AWS credentials (must be set manually)
AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:-CHANGE_ME}
AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY:-CHANGE_ME}

# Domain (optional)
DOMAIN_NAME=${DOMAIN_NAME:-}
HOSTED_ZONE_ID=${HOSTED_ZONE_ID:-}

# ArgoCD (optional)
ARGOCD_PASSWORD=${ARGOCD_PASSWORD:-CHANGE_ME}

# Grafana (optional)
GRAFANA_PASSWORD=${GRAFANA_PASSWORD:-CHANGE_ME}
EOF

    echo -e "${GREEN}✅ Secrets generated at $ENV_FILE${NC}"
    echo -e "${YELLOW}⚠️  Edit this file to add real credentials!${NC}"
fi

# ============================================
# 2. Export Secrets for Current Shell
# ============================================

set -a
source "$ENV_FILE"
set +a

echo -e "${GREEN}✅ Secrets loaded into environment${NC}"

# ============================================
# 3. Create SealedSecret for GitOps
# ============================================

echo -e "${YELLOW}🔒 Creating SealedSecret for $ENV...${NC}"

# Check if sealed-secrets controller is installed
if ! kubectl get namespace "$SEALED_NAMESPACE" &>/dev/null; then
    echo -e "${RED}❌ SealedSecrets controller not found!${NC}"
    echo -e "${YELLOW}Installing SealedSecrets...${NC}"

    helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets --force-update
    helm upgrade --install sealed-secrets sealed-secrets/sealed-secrets \
        --namespace "$SEALED_NAMESPACE" \
        --create-namespace \
        --wait

    echo -e "${GREEN}✅ SealedSecrets installed${NC}"
fi

# Create the sealed secret
SEALED_DIR="$ROOT_DIR/gitops/sealed-secrets/$ENV"
mkdir -p "$SEALED_DIR"

# Generate sealed secret from environment
kubectl create secret generic taskapp-secrets \
    --namespace taskapp-${ENV} \
    --dry-run=client \
    -o yaml \
    --from-literal=POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
    --from-literal=SECRET_KEY="$SECRET_KEY" \
    | kubeseal \
        --controller-namespace="$SEALED_NAMESPACE" \
        --format yaml \
    > "$SEALED_DIR/sealed-secret.yaml"

echo -e "${GREEN}✅ SealedSecret created at: $SEALED_DIR/sealed-secret.yaml${NC}"

# ============================================
# 4. Inject Secrets to Cluster (Optional)
# ============================================

echo -e "${YELLOW}🔑 Inject secrets to cluster? (y/N)${NC}"
read -r -n 1 response
echo
if [[ "$response" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Injecting secrets to cluster...${NC}"

    # Ensure namespace exists
    kubectl create namespace taskapp-${ENV} --dry-run=client -o yaml | kubectl apply -f -

    # Apply the sealed secret
    kubectl apply -f "$SEALED_DIR/sealed-secret.yaml"

    echo -e "${GREEN}✅ Secrets injected to cluster${NC}"
fi

# ============================================
# 5. Output Summary
# ============================================

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}✅ Secrets Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${YELLOW}📁 Secrets file: $ENV_FILE${NC}"
echo -e "${YELLOW}🔒 SealedSecret: $SEALED_DIR/sealed-secret.yaml${NC}"
echo -e "${YELLOW}📦 GitOps: Commit the sealed secret to git${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Edit $ENV_FILE if needed"
echo "  2. Commit gitops/sealed-secrets/$ENV/sealed-secret.yaml"
echo "  3. Run: make gitops-apply ENV=$ENV"
echo ""
echo -e "${YELLOW}⚠️  Remember to keep $ENV_FILE gitignored!${NC}"