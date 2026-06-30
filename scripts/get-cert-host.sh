#!/bin/bash
# ============================================
# Get/derive host for certificate based on environment
# ============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ENV=${1:-dev}
CLOUD=${2:-local}
HOST_PREFIX=${3:-taskapp}

# ============================================
# Get host based on environment
# ============================================

get_host_local() {
    # Local uses .local domain
    echo "${HOST_PREFIX}.local"
}

get_host_cloud() {
    # For cloud, try to get IP from Terraform first
    if [ -f "$ROOT_DIR/infra/terraform/.terraform-outputs.json" ]; then
        # Get the IP from Terraform outputs
        IP=$(cd "$ROOT_DIR/infra/terraform" && terraform output -raw control_plane_public_ips 2>/dev/null | head -n1)
        if [ -n "$IP" ]; then
            echo "$IP"
            return 0
        fi
    fi

    # Fallback: use environment variable
    if [ -n "$HOST" ]; then
        echo "$HOST"
        return 0
    fi

    # Final fallback: prompt user
    echo -e "${YELLOW}⚠️  Could not determine host automatically${NC}"
    echo -e "${YELLOW}Please enter your domain/IP:${NC}"
    read -r INPUT_HOST
    echo "$INPUT_HOST"
}

# ============================================
# Main
# ============================================

case "$CLOUD" in
    local)
        HOST=$(get_host_local)
        ;;
    aws)
        HOST=$(get_host_cloud)
        ;;
    *)
        echo -e "${RED}❌ Unknown CLOUD=$CLOUD${NC}"
        exit 1
        ;;
esac

echo "$HOST"