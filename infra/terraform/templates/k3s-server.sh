#!/bin/bash
set -e
echo "Installing k3s server with Calico CNI and Traefik disabled..."

# Install k3s server:
# 1. Disable Traefik (we use Nginx)
# 2. Disable Flannel (we use Calico for NetworkPolicy support)
# 3. Set Calico's required CIDR
curl -sfL https://get.k3s.io | \
INSTALL_K3S_VERSION="${k3s_version}" \
K3S_TOKEN="k3s-token-${environment}" \
INSTALL_K3S_EXEC="server --disable traefik --flannel-backend=none --cluster-cidr=192.168.0.0/16 --write-kubeconfig-mode 644" \
sh -

# Wait for k3s to be ready
sleep 15
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Install Calico CNI (Required for Capstone Advanced NetworkPolicy requirement)
echo "Installing Calico CNI for NetworkPolicy support..."
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml
sleep 10
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/custom-resources.yaml

echo "k3s server and Calico installed successfully!"
kubectl get nodes
