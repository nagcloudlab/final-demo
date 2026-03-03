#!/bin/bash
# Microservices Load Generator
# Generates realistic traffic patterns for demo purposes

GATEWAY_URL="${GATEWAY_URL:-http://localhost:30080}"
DURATION="${1:-60}"
RPS="${2:-5}"
DELAY=$(echo "scale=3; 1/$RPS" | bc)

echo "============================================"
echo "  Microservices Load Generator"
echo "============================================"
echo "  Target:     ${GATEWAY_URL}"
echo "  Duration:   ${DURATION}s"
echo "  Target RPS: ${RPS}"
echo "  Delay:      ${DELAY}s between requests"
echo "============================================"
echo ""

SUCCESS=0
FAIL=0
TOTAL=0
START_TIME=$(date +%s)

# Product IDs available in the system
PRODUCT_IDS=(1 2 3)

while true; do
  CURRENT_TIME=$(date +%s)
  ELAPSED=$((CURRENT_TIME - START_TIME))

  if [ "$ELAPSED" -ge "$DURATION" ]; then
    break
  fi

  # Randomize request type
  RAND=$((RANDOM % 10))

  if [ "$RAND" -lt 4 ]; then
    # 40% - GET products
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}:%{time_total}" --max-time 5 "${GATEWAY_URL}/api/gateway/products" 2>/dev/null)
    ENDPOINT="GET /products"
  elif [ "$RAND" -lt 7 ]; then
    # 30% - GET orders
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}:%{time_total}" --max-time 5 "${GATEWAY_URL}/api/gateway/orders" 2>/dev/null)
    ENDPOINT="GET /orders"
  elif [ "$RAND" -lt 9 ]; then
    # 20% - POST order (creates inter-service call to product-service!)
    PID=${PRODUCT_IDS[$((RANDOM % ${#PRODUCT_IDS[@]}))]}
    QTY=$((RANDOM % 5 + 1))
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}:%{time_total}" --max-time 5 \
      -X POST "${GATEWAY_URL}/api/gateway/orders" \
      -H "Content-Type: application/json" \
      -d "{\"productId\": ${PID}, \"quantity\": ${QTY}}" 2>/dev/null)
    ENDPOINT="POST /orders (pid=${PID},qty=${QTY})"
  else
    # 10% - Health check
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}:%{time_total}" --max-time 5 "${GATEWAY_URL}/api/gateway/health" 2>/dev/null)
    ENDPOINT="GET /health"
  fi

  HTTP_CODE=$(echo "$RESPONSE" | cut -d: -f1)
  RESPONSE_TIME=$(echo "$RESPONSE" | cut -d: -f2)
  TOTAL=$((TOTAL + 1))

  if [[ "$HTTP_CODE" =~ ^2 ]]; then
    SUCCESS=$((SUCCESS + 1))
    STATUS="✅"
  else
    FAIL=$((FAIL + 1))
    STATUS="❌"
  fi

  printf "[%3ds] %s HTTP %s | %6ss | %-35s | S:%d F:%d\n" "$ELAPSED" "$STATUS" "${HTTP_CODE:-ERR}" "${RESPONSE_TIME:-N/A}" "$ENDPOINT" "$SUCCESS" "$FAIL"

  sleep "$DELAY"
done

echo ""
echo "============================================"
echo "  Load Test Complete"
echo "============================================"
echo "  Duration:   ${DURATION}s"
echo "  Total:      ${TOTAL} requests"
echo "  Success:    ${SUCCESS}"
echo "  Failed:     ${FAIL}"
if [ "$TOTAL" -gt 0 ]; then
  SUCCESS_RATE=$((SUCCESS * 100 / TOTAL))
  echo "  Success Rate: ${SUCCESS_RATE}%"
fi
echo "============================================"
