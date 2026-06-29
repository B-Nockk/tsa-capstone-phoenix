#!/bin/bash
set -e

# ============================================
# Inject Secrets to GitHub
# Uses GH CLI to set repository secrets
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ENV=${1:-dev}
SECRETS_FILE="$ROOT_DIR/.secrets/$ENV.env"

echo -e "${GREEN}🔐 Injecting secrets to GitHub for $ENV...${NC}"

# Check if gh is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ GitHub CLI not found. Install with: brew install gh${NC}"
    exit 1
fi

# Check if logged in
if ! gh auth status &> /dev/null; then
    echo -e "${RED}❌ Not logged in to GitHub. Run: gh auth login${NC}"
    exit 1
fi

# Get repo info
REPO=$(gh repo view --json name,owner -q '.owner.login + "/" + .name' 2>/dev/null)
if [ -z "$REPO" ]; then
    echo -e "${RED}❌ Not in a GitHub repo. Run: gh repo set-default${NC}"
    exit 1
fi

echo -e "${GREEN}📦 Repository: $REPO${NC}"

# Check if secrets file exists
if [ ! -f "$SECRETS_FILE" ]; then
    echo -e "${YELLOW}⚠️  Secrets file not found: $SECRETS_FILE${NC}"
    echo -e "${YELLOW}Run: ./scripts/setup-secrets.sh $ENV${NC}"
    exit 1
fi

# Load secrets
set -a
source "$SECRETS_FILE"
set +a

# Inject each secret
echo -e "${YELLOW}📝 Setting secrets...${NC}"

inject_secret() {
    local name="$1"
    local value="$2"

    if [ -z "$value" ] || [ "$value" = "CHANGE_ME" ]; then
        echo -e "${YELLOW}⚠️  Skipping $name (not set)${NC}"
        return
    fi

    echo -e "  Setting $name..."
    echo "$value" | gh secret set "$name" --repo "$REPO" --body -
}

# Application secrets
inject_secret "POSTGRES_PASSWORD" "$POSTGRES_PASSWORD"
inject_secret "SECRET_KEY" "$SECRET_KEY"

# GitHub secrets
inject_secret "GHCR_PAT" "$GHCR_PAT"
inject_secret "GITHUB_TOKEN" "$GITHUB_TOKEN"

# AWS secrets
inject_secret "AWS_ACCESS_KEY_ID" "$AWS_ACCESS_KEY_ID"
inject_secret "AWS_SECRET_ACCESS_KEY" "$AWS_SECRET_ACCESS_KEY"

# Domain secrets
inject_secret "DOMAIN_NAME" "$DOMAIN_NAME"
inject_secret "HOSTED_ZONE_ID" "$HOSTED_ZONE_ID"

# ArgoCD secrets
inject_secret "ARGOCD_PASSWORD" "$ARGOCD_PASSWORD"

echo -e "${GREEN}✅ GitHub secrets injected!${NC}"
echo ""
echo -e "${YELLOW}View secrets: https://github.com/$REPO/settings/secrets/actions${NC}"