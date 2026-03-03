#!/bin/bash
# Run all chaos experiments one by one with observation pauses
set -uo pipefail

echo "=== CHAOS ENGINEERING DEMO ==="
echo ""
echo "Ensure services are healthy first..."
kubectl get pods -n microservices
echo ""

run_experiment() {
  local name=$1
  local file=$2
  local wait_time=${3:-45}
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🔥 Experiment: $name"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  kubectl apply -f "$file"
  echo "⏳ Observing for ${wait_time}s... (check pods, logs, and service responses)"
  echo "   Run in another terminal: kubectl get pods -n microservices -w"
  sleep $wait_time
  kubectl delete -f "$file" 2>/dev/null
  echo "✅ Experiment completed. Recovery period..."
  sleep 15
  kubectl get pods -n microservices
  echo ""
}

run_experiment "Pod Kill - Product Service" "chaos/experiments/pod-kill-product.yaml" 40
run_experiment "Network Delay - Product Service" "chaos/experiments/network-delay.yaml" 70
run_experiment "CPU Stress - Order Service" "chaos/experiments/cpu-stress.yaml" 70
run_experiment "Network Partition - Gateway<->Order" "chaos/experiments/network-partition.yaml" 40
run_experiment "Pod Failure - API Gateway" "chaos/experiments/pod-failure.yaml" 40
run_experiment "Pod Kill - Order Service" "chaos/experiments/pod-kill-order.yaml" 40

echo "=== ALL EXPERIMENTS COMPLETED ==="
echo "Check Chaos Mesh Dashboard: kubectl port-forward -n chaos-mesh svc/chaos-dashboard 2333:2333"
