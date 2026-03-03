#!/bin/bash
set -e
DEMO_DIR="$(cd "$(dirname "$0")" && pwd)"
TAG="${1:-latest}"
CLUSTER_NAME="k8s-demo"
DOCKER_HUB_USER="nagabhushanamn"

echo "Building all microservice images with tag: ${TAG}"
for service in product-service order-service api-gateway; do
  echo "Building ${service}..."
  docker build -t ${DOCKER_HUB_USER}/${service}:${TAG} ${DEMO_DIR}/${service}/
  docker push ${DOCKER_HUB_USER}/${service}:${TAG}
  echo "[ok] ${service}:${TAG} pushed to Docker Hub"
done
echo "All images built and pushed!"
