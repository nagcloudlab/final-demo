#!/bin/bash
# Steady state validation - run before and after chaos experiments
echo "=== Steady State Validation ==="
GATEWAY_URL="http://localhost:30080"
PASS=0
FAIL=0

check() {
  local name=$1
  local url=$2
  local expected=$3
  local response=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)
  if [ "$response" = "$expected" ]; then
    echo "✅ PASS: $name (HTTP $response)"
    PASS=$((PASS+1))
  else
    echo "❌ FAIL: $name (Expected HTTP $expected, Got HTTP $response)"
    FAIL=$((FAIL+1))
  fi
}

check "Gateway Health" "$GATEWAY_URL/api/gateway/health" "200"
check "Products via Gateway" "$GATEWAY_URL/api/gateway/products" "200"
check "Orders via Gateway" "$GATEWAY_URL/api/gateway/orders" "200"

PODS=$(kubectl get pods -n microservices --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
if [ "$PODS" -ge 4 ]; then
  echo "✅ PASS: Running pods count: $PODS (expected >= 4)"
  PASS=$((PASS+1))
else
  echo "❌ FAIL: Running pods count: $PODS (expected >= 4)"
  FAIL=$((FAIL+1))
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
