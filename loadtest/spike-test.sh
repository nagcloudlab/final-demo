#!/bin/bash
# Simulates a traffic spike - useful for showing auto-scaling behavior
GATEWAY_URL="${GATEWAY_URL:-http://localhost:30080}"

echo "=== Traffic Spike Test ==="
echo ""

echo "Phase 1: Normal load (2 req/s for 15s)..."
for i in $(seq 1 30); do
  curl -s -o /dev/null "${GATEWAY_URL}/api/gateway/products" &
  sleep 0.5
done
wait
echo "Done."

echo "Phase 2: SPIKE! (20 req/s for 10s)..."
for i in $(seq 1 200); do
  curl -s -o /dev/null "${GATEWAY_URL}/api/gateway/products" &
  curl -s -o /dev/null "${GATEWAY_URL}/api/gateway/orders" &
  sleep 0.1
done
wait
echo "Done."

echo "Phase 3: Cool down (2 req/s for 15s)..."
for i in $(seq 1 30); do
  curl -s -o /dev/null "${GATEWAY_URL}/api/gateway/products" &
  sleep 0.5
done
wait
echo "Done."

echo ""
echo "Spike test completed! Check Grafana for the traffic pattern."
