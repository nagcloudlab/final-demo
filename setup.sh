#!/bin/bash
set -e

echo "============================================"
echo "  Microservices CI/CD Demo - Full Setup"
echo "============================================"
echo ""

DEMO_DIR="$(cd "$(dirname "$0")" && pwd)"
CLUSTER_NAME="microservices-demo"
REGISTRY_NAME="kind-registry"
REGISTRY_PORT="5001"

# Step 1: Check prerequisites
echo "Step 1: Checking prerequisites..."
for cmd in docker kind kubectl helm; do
  if ! command -v $cmd &> /dev/null; then
    echo "ERROR: $cmd is not installed. Please install it first."
    exit 1
  fi
  echo "  [ok] $cmd found"
done
echo ""

# Step 2: Create local Docker registry
echo "Step 2: Setting up local Docker registry..."
if [ "$(docker inspect -f '{{.State.Running}}' "${REGISTRY_NAME}" 2>/dev/null)" != 'true' ]; then
  docker run -d --restart=always -p "${REGISTRY_PORT}:5000" --network bridge --name "${REGISTRY_NAME}" registry:2
  echo "  [ok] Registry started on localhost:${REGISTRY_PORT}"
else
  echo "  [ok] Registry already running"
fi
echo ""

# Step 3: Create Kind cluster
echo "Step 3: Creating Kind cluster..."
if kind get clusters 2>/dev/null | grep -q "${CLUSTER_NAME}"; then
  echo "  [ok] Cluster '${CLUSTER_NAME}' already exists"
else
  kind create cluster --name "${CLUSTER_NAME}" --config "${DEMO_DIR}/k8s/kind-config.yaml"
  echo "  [ok] Cluster created"
fi

# Connect registry to Kind network
if [ "$(docker inspect -f='{{json .NetworkSettings.Networks.kind}}' "${REGISTRY_NAME}" 2>/dev/null)" = 'null' ] || [ "$(docker inspect -f='{{json .NetworkSettings.Networks.kind}}' "${REGISTRY_NAME}" 2>/dev/null)" = '' ]; then
  docker network connect "kind" "${REGISTRY_NAME}" 2>/dev/null || true
fi

# Configure registry in cluster
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${REGISTRY_PORT}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF
echo ""

# Step 4: Create namespaces
echo "Step 4: Creating namespaces..."
kubectl apply -f "${DEMO_DIR}/k8s/namespace.yaml"
echo ""

# Step 5: Build and push Docker images
echo "Step 5: Building Docker images..."
for service in product-service order-service api-gateway; do
  echo "  Building ${service}..."
  docker build -t "localhost:${REGISTRY_PORT}/${service}:latest" "${DEMO_DIR}/${service}/"
  docker push "localhost:${REGISTRY_PORT}/${service}:latest"
  echo "  [ok] ${service} built and pushed"
done
echo ""

# Step 6: Deploy microservices to K8s
echo "Step 6: Deploying microservices..."
kubectl apply -f "${DEMO_DIR}/k8s/product-service/"
kubectl apply -f "${DEMO_DIR}/k8s/order-service/"
kubectl apply -f "${DEMO_DIR}/k8s/api-gateway/"
echo ""

# Step 7: Deploy Jenkins
echo "Step 7: Deploying Jenkins..."
kubectl apply -f "${DEMO_DIR}/k8s/jenkins/"
echo ""

# Step 8: Install NGINX Ingress Controller (optional)
echo "Step 8: Installing NGINX Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml 2>/dev/null || echo "  WARNING: Ingress controller installation skipped (may already exist)"
echo ""

# Step 9: Wait for deployments
echo "Step 9: Waiting for deployments to be ready..."
echo "  Waiting for product-service..."
kubectl rollout status deployment/product-service -n microservices --timeout=300s 2>/dev/null || echo "  WARNING: product-service still starting..."
echo "  Waiting for order-service..."
kubectl rollout status deployment/order-service -n microservices --timeout=300s 2>/dev/null || echo "  WARNING: order-service still starting..."
echo "  Waiting for api-gateway..."
kubectl rollout status deployment/api-gateway -n microservices --timeout=300s 2>/dev/null || echo "  WARNING: api-gateway still starting..."
echo ""

# Step 10: Show status
echo "============================================"
echo "  Setup Complete!"
echo "============================================"
echo ""
echo "Pod Status:"
kubectl get pods -n microservices
echo ""
kubectl get pods -n jenkins
echo ""
echo "Access Points:"
echo "  API Gateway:    http://localhost:30080/api/gateway/health"
echo "  Products:       http://localhost:30080/api/gateway/products"
echo "  Orders:         http://localhost:30080/api/gateway/orders"
echo "  Jenkins:        http://localhost:30000"
echo ""
echo "Jenkins Initial Password:"
echo "  kubectl exec -n jenkins \$(kubectl get pod -n jenkins -l app=jenkins -o jsonpath='{.items[0].metadata.name}') -- cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null || echo '  (Jenkins is still starting... run this command later)'"
echo ""
echo "To run Chaos Engineering experiments:"
echo "  cd ${DEMO_DIR} && bash chaos/install-chaos-mesh.sh"
echo "  bash chaos/run-all-experiments.sh"
