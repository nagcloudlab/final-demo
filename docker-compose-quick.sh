#!/bin/bash
echo "============================================"
echo "  Microservices Demo - Docker Compose Mode"
echo "============================================"
echo ""
echo "Starting all services..."
docker-compose up -d --build

echo ""
echo "Waiting for services to be healthy..."
sleep 30

echo ""
echo "Service Status:"
docker-compose ps

echo ""
echo "Testing endpoints..."
echo "  Products: $(curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/api/gateway/products)"
echo "  Orders:   $(curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/api/gateway/orders)"
echo "  Health:   $(curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/api/gateway/health)"

echo ""
echo "Access Points:"
echo "  API Gateway:  http://localhost:8080"
echo "  Products API: http://localhost:8081/api/products"
echo "  Orders API:   http://localhost:8082/api/orders"
echo "  Prometheus:   http://localhost:9090"
echo "  Grafana:      http://localhost:3000 (admin/admin)"
echo ""
echo "To stop: docker-compose down"
