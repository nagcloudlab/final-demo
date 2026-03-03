#!/bin/bash
set -e

echo "============================================"
echo "  Microservices CI/CD Demo - Full Setup"
echo "============================================"
echo ""

DEMO_DIR="$(cd "$(dirname "$0")" && pwd)"
CLUSTER_NAME="k8s-demo"
DOCKER_HUB_USER="nagabhushanamn"

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

# Step 2: Docker Hub Login
echo "Step 2: Docker Hub Login..."
docker login
echo ""

# Step 3: Create Kind cluster
echo "Step 3: Creating Kind cluster..."
if kind get clusters 2>/dev/null | grep -q "${CLUSTER_NAME}"; then
  echo "  [ok] Cluster '${CLUSTER_NAME}' already exists"
else
  kind create cluster --name "${CLUSTER_NAME}" --config "${DEMO_DIR}/k8s/kind-config.yaml"
  echo "  [ok] Cluster created"
fi
echo ""
kubectl cluster-info --context kind-${CLUSTER_NAME}
echo ""
kubectl get nodes
echo ""

# Step 4: Create namespaces
echo "Step 4: Creating namespaces..."
kubectl apply -f "${DEMO_DIR}/k8s/namespace.yaml"
echo ""

# Step 5: Build and push Docker images to Docker Hub
echo "Step 5: Building and pushing Docker images to Docker Hub..."
for service in product-service order-service api-gateway; do
  echo "  Building ${service}..."
  docker build -t "${DOCKER_HUB_USER}/${service}:latest" "${DEMO_DIR}/${service}/"
  echo "  Pushing ${service} to Docker Hub..."
  docker push "${DOCKER_HUB_USER}/${service}:latest"
  echo "  [ok] ${service} built and pushed"
done
echo ""

# Step 6: Build and load Jenkins custom image (stays local)
echo "Step 6: Building Jenkins custom image..."
docker build -t jenkins-custom:latest "${DEMO_DIR}/jenkins/"
kind load docker-image jenkins-custom:latest --name "${CLUSTER_NAME}"
echo "  [ok] jenkins-custom built and loaded into Kind"
echo ""

# Step 7: Deploy microservices to K8s
echo "Step 7: Deploying microservices..."
kubectl apply -f "${DEMO_DIR}/k8s/product-service/"
kubectl apply -f "${DEMO_DIR}/k8s/order-service/"
kubectl apply -f "${DEMO_DIR}/k8s/api-gateway/"
echo ""

# Step 8: Deploy Jenkins (with DinD sidecar for Docker support)
echo "Step 8: Deploying Jenkins..."
kubectl apply -f "${DEMO_DIR}/k8s/jenkins/"
echo ""

# Step 9: Install NGINX Ingress Controller
echo "Step 9: Installing NGINX Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml 2>/dev/null || echo "  [warn] Ingress controller may already exist"
echo ""

# Step 10: Wait for deployments
echo "Step 10: Waiting for deployments to be ready..."
echo "  Waiting for product-service..."
kubectl rollout status deployment/product-service -n microservices --timeout=300s 2>/dev/null || echo "  [warn] product-service still starting..."
echo "  Waiting for order-service..."
kubectl rollout status deployment/order-service -n microservices --timeout=300s 2>/dev/null || echo "  [warn] order-service still starting..."
echo "  Waiting for api-gateway..."
kubectl rollout status deployment/api-gateway -n microservices --timeout=300s 2>/dev/null || echo "  [warn] api-gateway still starting..."
echo "  Waiting for Jenkins..."
kubectl rollout status deployment/jenkins -n jenkins --timeout=300s 2>/dev/null || echo "  [warn] Jenkins still starting..."
echo ""

# Step 11: Setup external access via socat
echo "Step 11: Setting up external access..."
CONTROL_PLANE_IP=$(docker inspect "${CLUSTER_NAME}-control-plane" --format '{{.NetworkSettings.Networks.kind.IPAddress}}')
echo "  Kind control-plane IP: ${CONTROL_PLANE_IP}"

# Kill any existing socat processes for our ports
for port in 30000 30080 30090 30030; do
  pkill -f "socat.*TCP-LISTEN:${port}" 2>/dev/null || true
done
sleep 1

# Start socat forwarders for all NodePorts
for port in 30000 30080 30090 30030; do
  socat TCP-LISTEN:${port},fork,reuseaddr,bind=0.0.0.0 TCP:${CONTROL_PLANE_IP}:${port} &
  echo "  [ok] Port ${port} forwarded"
done
echo ""

# Step 12: Show status
echo "============================================"
echo "  Setup Complete!"
echo "============================================"
echo ""
echo "Pod Status:"
kubectl get pods -n microservices
echo ""
kubectl get pods -n jenkins
echo ""

VM_IP=$(hostname -I | awk '{print $1}')
echo "============================================"
echo "  Access Points (from your browser)"
echo "============================================"
echo "  API Gateway:  http://${VM_IP}:30080/api/gateway/health"
echo "  Products:     http://${VM_IP}:30080/api/gateway/products"
echo "  Orders:       http://${VM_IP}:30080/api/gateway/orders"
echo "  Jenkins:      http://${VM_IP}:30000"
echo "  Prometheus:   http://${VM_IP}:30090  (after monitoring setup)"
echo "  Grafana:      http://${VM_IP}:30030  (after monitoring setup)"
echo ""
echo "============================================"
echo "  Jenkins Initial Admin Password"
echo "============================================"
sleep 5
kubectl exec -n jenkins $(kubectl get pod -n jenkins -l app=jenkins -o jsonpath='{.items[0].metadata.name}') -c jenkins -- cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null || echo "  Jenkins is still starting... run this later:"
echo "  kubectl exec -n jenkins \$(kubectl get pod -n jenkins -l app=jenkins -o jsonpath='{.items[0].metadata.name}') -c jenkins -- cat /var/jenkins_home/secrets/initialAdminPassword"
echo ""
echo "============================================"
echo "  Next Steps"
echo "============================================"
echo "  1. Setup monitoring:  bash monitoring/setup-monitoring.sh"
echo "  2. Setup chaos mesh:  bash chaos/install-chaos-mesh.sh"
echo "  3. Run load test:     bash loadtest/generate-load.sh"
echo "  4. Run chaos:         bash chaos/run-all-experiments.sh"
echo ""
echo "  NOTE: Make sure Azure NSG allows inbound on ports 30000, 30080, 30090, 30030"
echo ""
