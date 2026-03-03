#!/bin/bash
echo "============================================"
echo "  Microservices CI/CD Demo - Teardown"
echo "============================================"
echo ""

CLUSTER_NAME="k8s-demo"

echo "Stopping socat port forwarders..."
for port in 30000 30080 30090 30030; do
  pkill -f "socat.*TCP-LISTEN:${port}" 2>/dev/null || true
done
echo "  [ok] Port forwarders stopped"

echo "Deleting Kind cluster..."
kind delete cluster --name "${CLUSTER_NAME}" 2>/dev/null && echo "  [ok] Cluster deleted" || echo "  [warn] No cluster found"

echo ""
echo "Teardown complete!"
