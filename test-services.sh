#!/bin/bash
echo "============================================"
echo "  Service Health Check"
echo "============================================"
echo ""

GATEWAY="http://localhost:30080"
PASS=0
FAIL=0

test_endpoint() {
  local name=$1
  local url=$2
  local response=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null)
  if [ "$response" = "200" ]; then
    echo "  PASS ${name}: HTTP ${response}"
    PASS=$((PASS+1))
  else
    echo "  FAIL ${name}: HTTP ${response:-TIMEOUT}"
    FAIL=$((FAIL+1))
  fi
}

echo "Testing via API Gateway (${GATEWAY}):"
test_endpoint "Gateway Health" "${GATEWAY}/api/gateway/health"
test_endpoint "Products"       "${GATEWAY}/api/gateway/products"
test_endpoint "Orders"         "${GATEWAY}/api/gateway/orders"

echo ""
echo "Kubernetes Status:"
kubectl get pods -n microservices -o wide
echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
