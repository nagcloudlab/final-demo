#!/bin/bash
# Install Chaos Mesh on Kind cluster using Helm
set -euo pipefail

echo "=== Installing Chaos Mesh on Kind Cluster ==="
echo ""

# Add Chaos Mesh Helm repository
echo "Adding Chaos Mesh Helm repository..."
helm repo add chaos-mesh https://charts.chaos-mesh.org
helm repo update

# Create namespace (ignore if already exists)
kubectl create ns chaos-mesh 2>/dev/null || true

# Install Chaos Mesh with Kind-compatible settings
echo "Installing Chaos Mesh v2.7.0..."
helm install chaos-mesh chaos-mesh/chaos-mesh \
  --namespace chaos-mesh \
  --set chaosDaemon.runtime=containerd \
  --set chaosDaemon.socketPath=/run/containerd/containerd.sock \
  --set dashboard.securityMode=false \
  --version 2.7.0

echo ""
echo "Waiting for Chaos Mesh pods..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=chaos-mesh -n chaos-mesh --timeout=120s

echo ""
echo "Chaos Mesh pods:"
kubectl get pods -n chaos-mesh

echo ""
echo "Chaos Mesh installed! Dashboard available via: kubectl port-forward -n chaos-mesh svc/chaos-dashboard 2333:2333"
