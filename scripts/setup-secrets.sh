#!/bin/bash
set -e

# ============================================
# Secrets Setup Script
# Generates, encrypts, and injects secrets
# ============================================

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================
# 1. Configuration & Overridable Variables
# ============================================

# Environment (passed as first argument, defaults to 'dev')
ENV=${1:-dev}

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${ROOT_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
SECRETS_DIR="${SECRETS_DIR:-$ROOT_DIR/.secrets}"
SEALED_DIR="${SEALED_DIR:-$ROOT_DIR/gitops/sealed-secrets/$ENV}"

# Kubernetes Namespaces & Names (Overridable via Environment)
APP_NAMESPACE="${APP_NAMESPACE:-taskapp-${ENV}}"
SECRET_NAME="${SECRET_NAME:-taskapp-secrets}"
SEALED_NAMESPACE="${SEALED_NAMESPACE:-sealed-secrets}"
SEALED_CONTROLLER_NAME="${SEALED_CONTROLLER_NAME:-sealed-secrets}" # Bitnami Helm chart default

# Helm Repo
SEALED_SECRETS_REPO="${SEALED_SECRETS_REPO:-https://bitnami.github.io/sealed-secrets}"

HELM_TEMPLATE_DIR="$ROOT_DIR/helm/taskapp/templates"
# TARGET_FILE="$HELM_TEMPLATE_DIR/sealedsecret-${ENV}.yaml"

# Automation flag (set to 'true' to skip interactive prompts, useful for CI/Make)
AUTO_INJECT="${AUTO_INJECT:-false}"

ENV_FILE="$SECRETS_DIR/$ENV.env"

# ============================================
# 2. Feedback: Show Configuration
# ============================================

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}🔐 Secrets Setup Configuration${NC}"
echo -e "${CYAN}========================================${NC}"
echo -e "Environment:       ${GREEN}$ENV${NC}"
echo -e "Root Directory:    ${YELLOW}$ROOT_DIR${NC}"
echo -e "Secrets File:      ${YELLOW}$ENV_FILE${NC}"
echo -e "App Namespace:     ${GREEN}$APP_NAMESPACE${NC}"
echo -e "Secret Name:       ${GREEN}$SECRET_NAME${NC}"
echo -e "Controller NS:     ${GREEN}$SEALED_NAMESPACE${NC}"
echo -e "Controller Name:   ${GREEN}$SEALED_CONTROLLER_NAME${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# ============================================
# 3. Load or Generate Secrets
# ============================================

mkdir -p "$SECRETS_DIR"

# Check if we should generate or use existing
# We only generate POSTGRES_PASSWORD and SECRET_KEY if they aren't already in the environment
if [ -z "$POSTGRES_PASSWORD" ] || [ -z "$SECRET_KEY" ]; then
    if [ -f "$ENV_FILE" ]; then
        echo -e "${YELLOW}⚠️  Secrets file exists: $ENV_FILE${NC}"
        echo -e "${YELLOW}Loading existing secrets...${NC}"
        set -a
        source "$ENV_FILE"
        set +a
    else
        echo -e "${YELLOW}📝 Generating new secrets for $ENV...${NC}"

        # Generate random passwords
        export POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d '\n')
        export SECRET_KEY=$(openssl rand -base64 32 | tr -d '\n')

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
else
    echo -e "${GREEN}✅ Using secrets already loaded in environment${NC}"
fi

# Ensure they are exported for the rest of the script
export POSTGRES_PASSWORD
export SECRET_KEY

# ============================================
# 4. old: Create SealedSecret for GitOps
# ============================================

# echo -e "${YELLOW}🔒 Creating SealedSecret for $ENV...${NC}"

# # Check if sealed-secrets controller is installed
# if ! kubectl get namespace "$SEALED_NAMESPACE" &>/dev/null; then
#     echo -e "${RED}❌ SealedSecrets controller not found in namespace '$SEALED_NAMESPACE'!${NC}"
#     echo -e "${YELLOW}Installing SealedSecrets...${NC}"

#     helm repo add sealed-secrets "$SEALED_SECRETS_REPO" --force-update
#     helm upgrade --install sealed-secrets sealed-secrets/sealed-secrets \
#         --namespace "$SEALED_NAMESPACE" \
#         --create-namespace \
#         --wait

#     echo -e "${GREEN}✅ SealedSecrets installed${NC}"
# fi

# # Create the sealed secret
# mkdir -p "$SEALED_DIR"

# # Generate sealed secret from environment
# kubectl create secret generic "$SECRET_NAME" \
#     --namespace "$APP_NAMESPACE" \
#     --dry-run=client \
#     -o yaml \
#     --from-literal=POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
#     --from-literal=SECRET_KEY="$SECRET_KEY" \
#     | kubeseal \
#         --controller-name="$SEALED_CONTROLLER_NAME" \
#         --controller-namespace="$SEALED_NAMESPACE" \
#         --format yaml \
#     > "$SEALED_DIR/sealed-secret.yaml"

# echo -e "${GREEN}✅ SealedSecret created at: $SEALED_DIR/sealed-secret.yaml${NC}"


echo -e "${YELLOW}🔒 Generating Automated SealedSecret for $ENV...${NC}"

# 1. Generate the raw sealed secret into a temporary file
kubectl create secret generic "$SECRET_NAME" \
    --namespace "$APP_NAMESPACE" \
    --dry-run=client \
    -o yaml \
    --from-literal=POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
    --from-literal=SECRET_KEY="$SECRET_KEY" \
    --from-literal=GRAFANA_PASSWORD="$GRAFANA_PASSWORD" \
    --from-literal=AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
    --from-literal=AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
    | kubeseal \
        --controller-name="$SEALED_CONTROLLER_NAME" \
        --controller-namespace="$SEALED_NAMESPACE" \
        --format yaml \
    > /tmp/sealed-${ENV}.yaml

# 2. Define the target Helm templates directory
# HELM_TEMPLATE_DIR="$ROOT_DIR/helm/taskapp/templates"
mkdir -p "$HELM_TEMPLATE_DIR"
TARGET_FILE="$HELM_TEMPLATE_DIR/sealedsecret-${ENV}.yaml"

# 3. Wrap the file in a Helm conditional so it only deploys to the matching environment
echo "{{- if eq .Values.namespace \"$APP_NAMESPACE\" }}" > "$TARGET_FILE"
cat /tmp/sealed-${ENV}.yaml >> "$TARGET_FILE"
echo "{{- end }}" >> "$TARGET_FILE"

# 4. Clean up
rm /tmp/sealed-${ENV}.yaml

echo -e "${GREEN}✅ Success! Automated Helm template created at: $TARGET_FILE${NC}"

# ============================================
# 5. Inject Secrets to Cluster (Optional)
# ============================================

# echo -e "${CYAN}========================================${NC}"
# echo -e "${YELLOW}⚠️  STEP 5 HAS BEEN SUN SETTED        ${NC}"
# echo -e "${CYAN}========================================${NC}"

# if [ "$AUTO_INJECT" = "true" ]; then
#     echo -e "${YELLOW}🔑 AUTO_INJECT=true: Injecting secrets to cluster automatically...${NC}"

#     # Ensure namespace exists
#     kubectl create namespace "$APP_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

#     # Apply the sealed secret
#     kubectl apply -f "$SEALED_DIR/sealed-secret.yaml"

#     echo -e "${GREEN}✅ Secrets injected to cluster${NC}"
# else
#     echo -e "${YELLOW}🔑 Inject secrets to cluster? (y/N)${NC}"
#     read -r -n 1 response
#     echo
#     if [[ "$response" =~ ^[Yy]$ ]]; then
#         echo -e "${YELLOW}Injecting secrets to cluster...${NC}"

#         # Ensure namespace exists
#         kubectl create namespace "$APP_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

#         # Apply the sealed secret
#         kubectl apply -f "$SEALED_DIR/sealed-secret.yaml"

#         echo -e "${GREEN}✅ Secrets injected to cluster${NC}"
#     else
#         echo -e "${YELLOW}⏭️  Skipping cluster injection.${NC}"
#     fi
# fi

# ============================================
# 5. Commit & Push (CI only — gated by AUTO_INJECT)
# ============================================
if [ "$AUTO_INJECT" = "true" ]; then
    echo -e "${YELLOW}📦 Committing generated SealedSecret to git...${NC}"
    cd "$ROOT_DIR"
    git config user.name "github-actions[bot]"
    git config user.email "github-actions[bot]@users.noreply.github.com"
    git add "$TARGET_FILE"
    if git diff --cached --quiet; then
        echo -e "${GREEN}✅ No changes to commit (sealed secret unchanged)${NC}"
    else
        git commit -m "chore: update sealed secret for $ENV [skip ci]"
        git push origin HEAD:${GITHUB_REF_NAME:-$(git branch --show-current)}
        echo -e "${GREEN}✅ Sealed secret committed and pushed${NC}"
    fi
else
    echo -e "${YELLOW}⏭️  AUTO_INJECT=false — skipping git commit (local/manual run)${NC}"
fi

# ============================================
# 6. Output Summary
# ============================================

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}✅ Secrets Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${YELLOW}📁 Secrets file: $ENV_FILE${NC}"
echo -e "${YELLOW}🔒 Helm Template: $TARGET_FILE${NC}"
echo -e "${YELLOW}📦 GitOps: Commit the sealed secret to git${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Edit $ENV_FILE if you need to change passwords manually"
echo "  2. Commit helm/taskapp/templates/sealedsecret-${ENV}.yaml"
echo "  3. ArgoCD or Helm will automatically apply it on the next sync!"
echo ""
echo -e "${YELLOW}⚠️  Remember to keep $ENV_FILE gitignored!${NC}"
