#!/bin/bash
set -e

echo "Installing k3s server..."

# Install k3s server
curl -sfL https://get.k3s.io | \
  INSTALL_K3S_VERSION="${k3s_version}" \
  K3S_TOKEN="k3s-token-${environment}" \
  INSTALL_K3S_EXEC="server --write-kubeconfig-mode 644" \
  sh -

# Wait for k3s to be ready
sleep 10

echo "k3s server installed successfully!"

# For debugging
kubectl get nodes