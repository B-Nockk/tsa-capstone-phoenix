#!/bin/bash
set -e

echo "Installing k3s agent..."
echo "Connecting to control plane at: ${control_plane_ip}"

# Install k3s agent
curl -sfL https://get.k3s.io | \
  INSTALL_K3S_VERSION="${k3s_version}" \
  K3S_URL="https://${control_plane_ip}:6443" \
  K3S_TOKEN="${node_token}" \
  sh -

echo "k3s agent installed successfully!"