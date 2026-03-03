#!/bin/bash
set -e
DEMO_DIR="$(cd "$(dirname "$0")" && pwd)"
TAG="${1:-latest}"

echo "Deploying all microservices with tag: ${TAG}..."
for service in product-service order-service api-gateway; do
  kubectl set image "deployment/${service}" "${service}=localhost:5001/${service}:${TAG}" -n microservices
  kubectl rollout status "deployment/${service}" -n microservices --timeout=120s
  echo "[ok] ${service} deployed"
done

echo ""
echo "All services deployed! Current pods:"
kubectl get pods -n microservices
