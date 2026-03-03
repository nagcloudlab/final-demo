#!/bin/bash
set -e
DEMO_DIR="$(cd "$(dirname "$0")" && pwd)"
REGISTRY_PORT="5001"
TAG="${1:-latest}"

echo "Building all microservice images with tag: ${TAG}"
for service in product-service order-service api-gateway; do
  echo "Building ${service}..."
  docker build -t "localhost:${REGISTRY_PORT}/${service}:${TAG}" "${DEMO_DIR}/${service}/"
  docker push "localhost:${REGISTRY_PORT}/${service}:${TAG}"
  echo "[ok] ${service}:${TAG} pushed to registry"
done
echo "All images built and pushed!"
