#!/bin/bash
# Lightweight continuous load - run during chaos experiments
# Usage: ./continuous-load.sh [rps]

GATEWAY_URL="${GATEWAY_URL:-http://localhost:30080}"
RPS="${1:-2}"
DELAY=$(echo "scale=3; 1/$RPS" | bc)

echo "Continuous load generator started (${RPS} req/s). Ctrl+C to stop."
echo "Target: ${GATEWAY_URL}"
echo ""

TOTAL=0
SUCCESS=0
FAIL=0

trap 'echo ""; echo "Stopped. Total: $TOTAL, Success: $SUCCESS, Failed: $FAIL"; exit 0' INT

while true; do
  RAND=$((RANDOM % 3))
  case $RAND in
    0) URL="${GATEWAY_URL}/api/gateway/products" ;;
    1) URL="${GATEWAY_URL}/api/gateway/orders" ;;
    2) URL="${GATEWAY_URL}/api/gateway/health" ;;
  esac

  CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 "$URL" 2>/dev/null)
  TOTAL=$((TOTAL+1))

  if [[ "$CODE" =~ ^2 ]]; then
    SUCCESS=$((SUCCESS+1))
  else
    FAIL=$((FAIL+1))
    echo "[$(date +%H:%M:%S)] ❌ HTTP ${CODE:-ERR} - ${URL}"
  fi

  sleep "$DELAY"
done
