#!/bin/bash
echo "============================================"
echo "  Microservices CI/CD Demo - Teardown"
echo "============================================"
echo ""

CLUSTER_NAME="microservices-demo"
REGISTRY_NAME="kind-registry"

echo "Deleting Kind cluster..."
kind delete cluster --name "${CLUSTER_NAME}" 2>/dev/null && echo "  [ok] Cluster deleted" || echo "  WARNING: No cluster found"

echo "Stopping local registry..."
docker rm -f "${REGISTRY_NAME}" 2>/dev/null && echo "  [ok] Registry removed" || echo "  WARNING: No registry found"

echo ""
echo "Teardown complete!"
