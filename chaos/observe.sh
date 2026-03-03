#!/bin/bash
# Run this in a separate terminal to observe service health during chaos experiments
echo "Monitoring services... (Ctrl+C to stop)"
while true; do
  echo "--- $(date) ---"
  echo "Pod Status:"
  kubectl get pods -n microservices -o wide
  echo ""
  echo "Service Health Check (via Gateway NodePort 30080):"
  curl -s -o /dev/null -w "Gateway:  HTTP %{http_code} - %{time_total}s\n" http://localhost:30080/api/gateway/health 2>/dev/null || echo "Gateway: UNREACHABLE"
  curl -s -o /dev/null -w "Products: HTTP %{http_code} - %{time_total}s\n" http://localhost:30080/api/gateway/products 2>/dev/null || echo "Products: UNREACHABLE"
  curl -s -o /dev/null -w "Orders:   HTTP %{http_code} - %{time_total}s\n" http://localhost:30080/api/gateway/orders 2>/dev/null || echo "Orders: UNREACHABLE"
  echo ""
  sleep 5
done
