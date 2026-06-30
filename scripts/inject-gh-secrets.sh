#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

SECRETS_FILE="$ROOT_DIR/.env"
VARS_FILE="$ROOT_DIR/.gh_vars"

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}🔐 GitHub Configuration Injector        ${NC}"
echo -e "${CYAN}========================================${NC}"

if ! command -v gh &> /dev/null; then echo -e "${RED}❌ gh CLI not found${NC}"; exit 1; fi
if ! gh auth status &> /dev/null; then echo -e "${RED}❌ Not logged in to GitHub${NC}"; exit 1; fi

REPO=$(gh repo view --json name,owner -q '.owner.login + "/" + .name' 2>/dev/null)
echo -e "${GREEN}📦 Repository: $REPO${NC}"
echo ""

# ============================================
# Universal Injection Function
# ============================================
inject_from_file() {
    local type="$1" # "secret" or "variable"
    local file="$2"

    if [ ! -f "$file" ]; then
        echo -e "${YELLOW}⚠️  File not found: $file (Skipping)${NC}"
        return
    fi

    echo -e "${GREEN}🔍 Reading from $(basename $file)...${NC}"

    # Read line by line, preserving spaces and JSON brackets
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue

        # Remove 'export ' prefix if it exists
        line="${line#export }"

        # Split into key and value safely
        key="${line%%=*}"
        value="${line#*=}"

        # Strip surrounding quotes from value
        value=$(echo "$value" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")

        if [ -z "$value" ] || [ "$value" = "CHANGE_ME" ]; then
            echo -e "${YELLOW}  ⚠️  Skipping $key (empty or CHANGE_ME)${NC}"
            continue
        fi

        echo -e "  Setting ${CYAN}$type${NC}: $key..."
        if [ "$type" == "secret" ]; then
            echo "$value" | gh secret set "$key" --repo "$REPO" --body -
        else
            echo "$value" | gh variable set "$key" --repo "$REPO" --body -
        fi
    done < "$file"
    echo ""
}

# ============================================
# Execute
# ============================================
inject_from_file "secret" "$SECRETS_FILE"
inject_from_file "variable" "$VARS_FILE"

echo -e "${CYAN}========================================${NC}"
echo -e "${GREEN}✅ GitHub Configuration Complete!${NC}"
echo -e "${CYAN}========================================${NC}"
echo -e "${YELLOW}🔗 Secrets:  https://github.com/$REPO/settings/secrets/actions${NC}"
echo -e "${YELLOW}🔗 Variables: https://github.com/$REPO/settings/variables/actions${NC}"
