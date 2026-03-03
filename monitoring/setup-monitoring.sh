#!/bin/bash
set -e
echo "=== Setting up Monitoring Stack ==="

DEMO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "Creating monitoring namespace..."
kubectl apply -f "${DEMO_DIR}/k8s/monitoring/namespace.yaml"

echo "Deploying Prometheus..."
kubectl apply -f "${DEMO_DIR}/k8s/monitoring/prometheus-rbac.yaml"
kubectl apply -f "${DEMO_DIR}/k8s/monitoring/prometheus-config.yaml"
kubectl apply -f "${DEMO_DIR}/k8s/monitoring/prometheus-deployment.yaml"
kubectl apply -f "${DEMO_DIR}/k8s/monitoring/prometheus-service.yaml"

echo "Deploying Grafana..."
kubectl apply -f "${DEMO_DIR}/k8s/monitoring/grafana-datasource.yaml"
kubectl apply -f "${DEMO_DIR}/k8s/monitoring/grafana-dashboard-config.yaml"
kubectl apply -f "${DEMO_DIR}/k8s/monitoring/grafana-dashboard.yaml"
kubectl apply -f "${DEMO_DIR}/k8s/monitoring/grafana-deployment.yaml"
kubectl apply -f "${DEMO_DIR}/k8s/monitoring/grafana-service.yaml"

echo "Waiting for pods..."
kubectl rollout status deployment/prometheus -n monitoring --timeout=120s
kubectl rollout status deployment/grafana -n monitoring --timeout=120s

echo ""
echo "Monitoring Stack Ready!"
echo "   Prometheus: http://localhost:30090"
echo "   Grafana:    http://localhost:30030 (admin/admin)"
echo ""
echo "Pre-configured dashboard: Microservices Monitor"
