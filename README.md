# Microservices CI/CD & Chaos Engineering Demo

```
 _____ _____    _____ ____     ____  _____ __  __  ___
|  ___/  ___|  / ____|  _ \   |  _ \| ____|  \/  |/ _ \
| |   | (___  | |    | | | |  | | | |  _| | |\/| | | | |
| |    \___ \ | |    | |_| |  | |_| | |___| |  | | |_| |
|_|    ____) | \____ |____/   |____/|_____|_|  |_|\___/
         CI/CD Pipeline + Chaos Engineering Workshop
```

```
[Spring Boot 3]  [Docker]  [Kubernetes]  [Jenkins]  [Prometheus]  [Grafana]  [Chaos Mesh]  [Resilience4j]
```

A hands-on training project that demonstrates a complete microservices ecosystem with CI/CD pipelines, observability, and chaos engineering. Built for the **final session** of the DevOps workshop, this project ties together everything students have learned: containerization, orchestration, continuous delivery, monitoring, and resilience testing.

---

## Table of Contents

- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Services API Reference](#services-api-reference)
- [CI/CD Pipeline Details](#cicd-pipeline-details)
- [Monitoring Setup](#monitoring-setup)
- [Chaos Engineering Experiments](#chaos-engineering-experiments)
- [Load Testing](#load-testing)
- [Key Concepts Covered](#key-concepts-covered)
- [Useful Commands Quick Reference](#useful-commands-quick-reference)
- [Access Points Summary](#access-points-summary)
- [Troubleshooting](#troubleshooting)
- [Cleanup](#cleanup)

---

## Architecture

### Diagram 1: Microservices Architecture

Shows how the three services communicate. The API Gateway acts as the single entry point, with circuit breakers protecting against downstream failures. The order-service calls the product-service directly for product validation when creating orders.

```
┌─────────────────────────────────────────────────────────┐
│                        Client                           │
└───────────────────────┬─────────────────────────────────┘
                        │ HTTP
                        ▼
┌─────────────────────────────────────────────────────────┐
│                API Gateway (:8080)                       │
│           [Circuit Breaker + Retry]                      │
│      ┌──────────┐              ┌──────────┐             │
│      │ Product   │              │  Order   │             │
│      │ Proxy     │              │  Proxy   │             │
│      └─────┬─────┘              └────┬─────┘             │
└────────────┼─────────────────────────┼──────────────────┘
             │                         │
       ┌─────▼───────┐          ┌──────▼──────┐
       │   Product    │◄─────────│    Order    │
       │   Service    │ validates│   Service   │
       │   (:8081)    │ products │   (:8082)   │
       └─────────────┘          └─────────────┘
```

**Key interactions:**
- **Client --> API Gateway**: All external traffic enters through the gateway on port 8080 (NodePort 30080 on K8s)
- **API Gateway --> Product Service**: Proxied via `ProductServiceProxy` with Resilience4j `@CircuitBreaker` and `@Retry`
- **API Gateway --> Order Service**: Proxied via `OrderServiceProxy` with Resilience4j `@CircuitBreaker` and `@Retry`
- **Order Service --> Product Service**: Direct REST call via `ProductServiceClient` to validate product ID and fetch price when creating orders

### Diagram 2: CI/CD Pipeline Flow

The Jenkins pipeline automates the full path from code commit to production deployment with health verification.

```
┌──────┐   ┌────────┐   ┌───────┐   ┌────────┐   ┌──────┐   ┌────────┐   ┌────────┐
│ Git  │──▶│Jenkins │──▶│ Maven │──▶│ Docker │──▶│ Push │──▶│Deploy  │──▶│Verify  │
│ Push │   │Trigger │   │ Build │   │ Build  │   │to Reg│   │to K8s  │   │Health  │
└──────┘   └────────┘   └───────┘   └────────┘   └──────┘   └────────┘   └────────┘
                          │    │
                          │    ▼
                          │  ┌───────┐
                          └─▶│ Test  │
                             └───────┘
```

**Pipeline stages:**
1. **Checkout** -- Pull source code from SCM
2. **Maven Build** -- `mvn clean package -DskipTests` (parallel for all 3 services in full pipeline)
3. **Test** -- `mvn test` runs unit tests (parallel for all 3 services in full pipeline)
4. **Docker Build** -- Multi-stage Dockerfile builds optimized JRE images
5. **Push to Registry** -- Push tagged images to local registry at `localhost:5001`
6. **Deploy to K8s** -- Rolling update via `kubectl set image` with rollout status verification
7. **Integration Test** -- Health endpoint check confirms deployment success

### Diagram 3: Kubernetes Deployment Topology

All components run inside a Kind cluster with dedicated namespaces for isolation.

```
┌──────────────────────────────────────────────────────────────────┐
│                      Kind K8s Cluster                            │
│                   (microservices-demo)                            │
│                                                                  │
│  ┌─ microservices namespace ──────────────────────────────────┐  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │  │
│  │  │product-service│  │order-service │  │ api-gateway  │     │  │
│  │  │ (2 replicas) │  │ (2 replicas) │  │ (2 replicas) │     │  │
│  │  │ ClusterIP    │  │ ClusterIP    │  │ NodePort     │     │  │
│  │  │ :8081        │  │ :8082        │  │ :8080/30080  │     │  │
│  │  └──────────────┘  └──────────────┘  └──────────────┘     │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌─ jenkins namespace ──┐  ┌─ monitoring namespace ──────────┐  │
│  │  ┌────────────────┐  │  │  ┌────────────┐ ┌────────────┐ │  │
│  │  │    Jenkins     │  │  │  │ Prometheus │ │  Grafana   │ │  │
│  │  │ NodePort:30000 │  │  │  │ NP:30090   │ │ NP:30030   │ │  │
│  │  └────────────────┘  │  │  └────────────┘ └────────────┘ │  │
│  └──────────────────────┘  └─────────────────────────────────┘  │
│                                                                  │
│  ┌─ chaos-mesh namespace ─┐  ┌─ Local Docker Registry ───────┐  │
│  │  Chaos Mesh Controller │  │  localhost:5001 (kind-registry)│  │
│  │  Chaos Daemon          │  │  Stores all service images     │  │
│  │  Dashboard (:2333)     │  └────────────────────────────────┘  │
│  └────────────────────────┘                                      │
└──────────────────────────────────────────────────────────────────┘
```

### Diagram 4: Chaos Engineering Observability Loop

Chaos experiments inject failures while monitoring captures the impact and circuit breakers provide resilience.

```
  Chaos Mesh                      Monitoring
  ┌────────────┐                 ┌────────────┐
  │ Pod Kill   │                 │ Prometheus  │──▶ Scrapes metrics
  │ Net Delay  │──▶ Injects ──▶ │             │    every 5s
  │ CPU Stress │    Failures     └──────┬──────┘
  │ Partition  │                        │
  │ Pod Failure│                        ▼
  │ HTTP Chaos │                 ┌────────────┐
  └────────────┘                 │  Grafana   │──▶ Visualizes impact
       │                         └────────────┘    in real-time
       │                               │
       ▼                               ▼
  ┌────────────┐                 ┌────────────┐
  │ Services   │──▶ Circuit ──▶  │ Dashboard  │
  │ Degrade    │    Breaker      │ Shows:     │
  │ Gracefully │    Activates    │  - Req Rate│
  │            │                 │  - Latency │
  └────────────┘                 │  - Errors  │
       │                         │  - JVM Mem │
       ▼                         │  - Threads │
  ┌────────────┐                 │  - Up/Down │
  │ K8s Self-  │                 └────────────┘
  │ Healing    │──▶ Pods restart automatically
  │ (liveness/ │    via liveness/readiness probes
  │  readiness)│
  └────────────┘
```

---

## Project Structure

```
final-demo/
├── README.md                           # This file
├── setup.sh                            # One-command full environment setup
├── teardown.sh                         # Clean up everything
├── build-images.sh                     # Build & push all Docker images
├── deploy.sh                           # Deploy/update services in K8s
├── test-services.sh                    # Health check all endpoints
├── docker-compose.yml                  # Local dev environment (all services + monitoring)
├── docker-compose-quick.sh             # Quick start script for Docker Compose mode
│
├── product-service/                    # Product catalog microservice (:8081)
│   ├── Dockerfile                      #   Multi-stage Docker build
│   ├── pom.xml                         #   Maven dependencies (Spring Boot, Actuator, Micrometer)
│   └── src/
│       ├── main/
│       │   ├── java/com/demo/product/
│       │   │   ├── ProductServiceApplication.java
│       │   │   ├── controller/
│       │   │   │   └── ProductController.java       # REST: GET/POST /api/products
│       │   │   └── model/
│       │   │       └── Product.java                  # Product entity (id, name, price, description)
│       │   └── resources/
│       │       └── application.yml                   # Port 8081, Prometheus metrics enabled
│       └── test/
│           └── java/com/demo/product/
│               └── ProductControllerTest.java        # Unit tests
│
├── order-service/                      # Order management microservice (:8082)
│   ├── Dockerfile                      #   Multi-stage Docker build
│   ├── pom.xml                         #   Maven dependencies
│   └── src/
│       ├── main/
│       │   ├── java/com/demo/order/
│       │   │   ├── OrderServiceApplication.java
│       │   │   ├── controller/
│       │   │   │   └── OrderController.java          # REST: GET/POST /api/orders
│       │   │   ├── dto/
│       │   │   │   └── ProductDTO.java               # DTO for product-service responses
│       │   │   ├── model/
│       │   │   │   └── Order.java                    # Order entity
│       │   │   └── service/
│       │   │       └── ProductServiceClient.java     # REST client -> product-service
│       │   └── resources/
│       │       └── application.yml                   # Port 8082, product-service URL config
│       └── test/
│           └── java/com/demo/order/
│               └── OrderControllerTest.java          # Unit tests
│
├── api-gateway/                        # API Gateway with circuit breakers (:8080)
│   ├── Dockerfile                      #   Multi-stage Docker build
│   ├── pom.xml                         #   Maven dependencies (Spring Boot, Resilience4j)
│   └── src/
│       ├── main/
│       │   ├── java/com/demo/gateway/
│       │   │   ├── ApiGatewayApplication.java
│       │   │   ├── controller/
│       │   │   │   └── GatewayController.java        # Gateway endpoints, circuit breaker status
│       │   │   └── service/
│       │   │       ├── ProductServiceProxy.java      # @CircuitBreaker + @Retry for products
│       │   │       └── OrderServiceProxy.java        # @CircuitBreaker + @Retry for orders
│       │   └── resources/
│       │       └── application.yml                   # Resilience4j config, service URLs
│       └── test/
│           └── java/com/demo/gateway/
│               └── ApiGatewayTest.java               # Unit tests
│
├── k8s/                                # Kubernetes manifests
│   ├── kind-config.yaml                #   Kind cluster config (2 nodes, port mappings, registry)
│   ├── namespace.yaml                  #   microservices + jenkins namespaces
│   ├── ingress.yaml                    #   NGINX Ingress rules
│   ├── product-service/
│   │   ├── deployment.yaml             #   2 replicas, liveness/readiness probes, resource limits
│   │   └── service.yaml                #   ClusterIP on port 8081
│   ├── order-service/
│   │   ├── deployment.yaml             #   2 replicas, env vars for product-service URL
│   │   └── service.yaml                #   ClusterIP on port 8082
│   ├── api-gateway/
│   │   ├── deployment.yaml             #   2 replicas, env vars for both service URLs
│   │   └── service.yaml                #   NodePort 30080
│   ├── jenkins/
│   │   ├── deployment.yaml             #   Jenkins LTS, 1 replica, emptyDir volume
│   │   ├── service.yaml                #   NodePort 30000 (UI) + 50000 (agent)
│   │   └── rbac.yaml                   #   ServiceAccount, ClusterRole, ClusterRoleBinding
│   └── monitoring/
│       ├── namespace.yaml              #   monitoring namespace
│       ├── prometheus-rbac.yaml        #   Prometheus RBAC for scraping
│       ├── prometheus-config.yaml      #   Scrape configs for all 3 services
│       ├── prometheus-deployment.yaml  #   Prometheus deployment
│       ├── prometheus-service.yaml     #   NodePort 30090
│       ├── grafana-datasource.yaml     #   Auto-configured Prometheus datasource
│       ├── grafana-dashboard-config.yaml   # Dashboard provisioning config
│       ├── grafana-dashboard.yaml      #   Pre-built "Microservices Monitor" dashboard
│       ├── grafana-deployment.yaml     #   Grafana deployment (admin/admin)
│       └── grafana-service.yaml        #   NodePort 30030
│
├── jenkins/                            # Jenkins pipeline definitions
│   ├── Jenkinsfile-product-service     #   Individual pipeline for product-service
│   ├── Jenkinsfile-order-service       #   Individual pipeline for order-service
│   ├── Jenkinsfile-api-gateway         #   Individual pipeline for api-gateway
│   └── Jenkinsfile-full-pipeline       #   Full pipeline: parallel build/test all 3 services
│
├── chaos/                              # Chaos engineering experiments
│   ├── install-chaos-mesh.sh           #   Helm install of Chaos Mesh v2.7.0
│   ├── run-all-experiments.sh          #   Run all experiments sequentially with pauses
│   ├── observe.sh                      #   Continuous health monitoring (run in separate terminal)
│   ├── steady-state-test.sh            #   Validate system health before/after chaos
│   └── experiments/
│       ├── pod-kill-product.yaml       #   Kill one product-service pod every 2 min
│       ├── pod-kill-order.yaml         #   Kill one order-service pod every 2 min
│       ├── network-delay.yaml          #   500ms latency on product-service (60s)
│       ├── network-partition.yaml      #   Partition api-gateway from order-service (30s)
│       ├── cpu-stress.yaml             #   80% CPU stress on order-service (60s)
│       ├── pod-failure.yaml            #   Fail one api-gateway pod (30s)
│       └── http-chaos.yaml             #   Inject HTTP 500 on product-service /api/products (30s)
│
├── loadtest/                           # Load generation scripts
│   ├── generate-load.sh               #   Full load generator with mixed traffic patterns
│   ├── continuous-load.sh             #   Lightweight continuous load for chaos experiments
│   └── spike-test.sh                  #   Three-phase spike test (normal -> spike -> cool down)
│
└── monitoring/                         # Monitoring configuration
    ├── setup-monitoring.sh             #   Deploy full Prometheus + Grafana stack to K8s
    └── prometheus-local.yml            #   Prometheus config for Docker Compose mode
```

---

## Prerequisites

| Tool | Purpose | Install |
|------|---------|---------|
| **Docker** | Container runtime | [docs.docker.com/get-docker](https://docs.docker.com/get-docker/) |
| **Kind** | Local K8s clusters | `go install sigs.k8s.io/kind@latest` or [kind.sigs.k8s.io](https://kind.sigs.k8s.io/) |
| **kubectl** | K8s CLI | [kubernetes.io/docs/tasks/tools](https://kubernetes.io/docs/tasks/tools/) |
| **Helm** | K8s package manager | [helm.sh/docs/intro/install](https://helm.sh/docs/intro/install/) |
| **Maven** | Java builds (local dev) | `sudo apt install maven` or [maven.apache.org](https://maven.apache.org/) |
| **Java 17+** | Runtime (local dev) | `sudo apt install openjdk-17-jdk` |
| **curl** | API testing | Pre-installed on most systems |
| **bc** | Load test math | `sudo apt install bc` |

---

## Quick Start

### Option 1: Docker Compose (Local Development)

The fastest way to get all services running. Ideal for exploring the APIs and testing locally. Includes Prometheus and Grafana.

```bash
# Start everything
docker-compose up -d --build

# Or use the quick-start script
bash docker-compose-quick.sh
```

Wait approximately 30 seconds for services to become healthy, then test:

```bash
# Test endpoints
curl http://localhost:8080/api/gateway/health
curl http://localhost:8080/api/gateway/products
curl http://localhost:8080/api/gateway/orders

# Check service status
docker-compose ps
```

**Docker Compose access points:**

| Service | URL |
|---------|-----|
| API Gateway | http://localhost:8080 |
| Product Service (direct) | http://localhost:8081/api/products |
| Order Service (direct) | http://localhost:8082/api/orders |
| Prometheus | http://localhost:9090 |
| Grafana | http://localhost:3000 (admin/admin) |

```bash
# Stop everything
docker-compose down
```

### Option 2: Kind Kubernetes Cluster (Full Demo)

The complete setup with Kubernetes, Jenkins, monitoring, and support for chaos engineering. This is the recommended mode for the training session.

```bash
# One command does it all:
bash setup.sh
```

This script will:
1. Check that all prerequisites are installed
2. Create a local Docker registry (`localhost:5001`)
3. Create a Kind cluster (`microservices-demo`) with 2 nodes
4. Connect the registry to the Kind network
5. Create `microservices` and `jenkins` namespaces
6. Build and push all 3 Docker images
7. Deploy microservices (2 replicas each)
8. Deploy Jenkins
9. Install NGINX Ingress Controller
10. Wait for all deployments to be ready

After setup completes, optionally add monitoring and chaos engineering:

```bash
# Add Prometheus + Grafana monitoring stack
bash monitoring/setup-monitoring.sh

# Add Chaos Mesh for chaos engineering
bash chaos/install-chaos-mesh.sh
```

Test the deployment:

```bash
bash test-services.sh
```

### Option 3: Manual Step-by-Step

For those who want to understand each step individually:

```bash
# 1. Create the Kind cluster
kind create cluster --name microservices-demo --config k8s/kind-config.yaml

# 2. Start a local Docker registry
docker run -d --restart=always -p 5001:5000 --network bridge --name kind-registry registry:2
docker network connect kind kind-registry

# 3. Create namespaces
kubectl apply -f k8s/namespace.yaml

# 4. Build and push images
docker build -t localhost:5001/product-service:latest product-service/
docker push localhost:5001/product-service:latest

docker build -t localhost:5001/order-service:latest order-service/
docker push localhost:5001/order-service:latest

docker build -t localhost:5001/api-gateway:latest api-gateway/
docker push localhost:5001/api-gateway:latest

# 5. Deploy to Kubernetes
kubectl apply -f k8s/product-service/
kubectl apply -f k8s/order-service/
kubectl apply -f k8s/api-gateway/

# 6. Wait for rollout
kubectl rollout status deployment/product-service -n microservices
kubectl rollout status deployment/order-service -n microservices
kubectl rollout status deployment/api-gateway -n microservices

# 7. Verify
kubectl get pods -n microservices
curl http://localhost:30080/api/gateway/health
```

---

## Services API Reference

### Product Service (`:8081`)

Manages the product catalog. Ships with 3 pre-loaded products.

| Method | Endpoint | Description | Example Response |
|--------|----------|-------------|------------------|
| `GET` | `/api/products` | List all products | `[{"id":1,"name":"Laptop","price":999.99,"description":"High-performance laptop with 16GB RAM"}, ...]` |
| `GET` | `/api/products/{id}` | Get product by ID | `{"id":1,"name":"Laptop","price":999.99,"description":"..."}` |
| `POST` | `/api/products` | Create a new product | Request: `{"name":"Monitor","price":299.99,"description":"4K display"}` |
| `GET` | `/api/products/health` | Service health check | `"Product Service is UP!"` |
| `GET` | `/actuator/health` | Spring Boot health | `{"status":"UP"}` |
| `GET` | `/actuator/prometheus` | Prometheus metrics | Micrometer metrics in Prometheus format |

### Order Service (`:8082`)

Manages orders. Calls product-service to validate products and fetch prices when creating new orders.

| Method | Endpoint | Description | Example Response |
|--------|----------|-------------|------------------|
| `GET` | `/api/orders` | List all orders | `[{"id":1,"productId":1,"productName":"Laptop","quantity":2,"totalPrice":1999.98,"status":"CONFIRMED"}, ...]` |
| `GET` | `/api/orders/{id}` | Get order by ID | `{"id":1,"productId":1,...}` |
| `POST` | `/api/orders` | Create order (calls product-service) | Request: `{"productId":1,"quantity":3}` |
| `GET` | `/api/orders/with-products` | Orders enriched with live product details | Includes `productDetails` and `productServiceStatus` fields |
| `GET` | `/api/orders/service-health` | Inter-service health | `{"orderService":"UP","productService":"UP","interServiceCommunication":"HEALTHY"}` |
| `GET` | `/api/orders/health` | Service health check | `"Order Service is UP!"` |
| `GET` | `/actuator/health` | Spring Boot health | `{"status":"UP"}` |
| `GET` | `/actuator/prometheus` | Prometheus metrics | Micrometer metrics in Prometheus format |

### API Gateway (`:8080`)

Single entry point for all clients. Provides circuit breakers and fallback responses.

| Method | Endpoint | Description | Notes |
|--------|----------|-------------|-------|
| `GET` | `/api/gateway/products` | Proxy to product-service | Circuit breaker + retry; returns fallback on failure |
| `GET` | `/api/gateway/orders` | Proxy to order-service | Circuit breaker + retry; returns fallback on failure |
| `GET` | `/api/gateway/health` | Aggregated health of all services | Shows status of gateway, product-service, order-service |
| `GET` | `/api/gateway/circuit-status` | Circuit breaker state | Shows state (CLOSED/OPEN/HALF_OPEN), failure rate, call counts |
| `GET` | `/actuator/health` | Spring Boot health | Includes circuit breaker health indicators |
| `GET` | `/actuator/prometheus` | Prometheus metrics | Micrometer metrics in Prometheus format |

**Circuit Breaker Configuration (Resilience4j):**

| Parameter | Value | Description |
|-----------|-------|-------------|
| `slidingWindowSize` | 5 | Number of calls in the sliding window |
| `minimumNumberOfCalls` | 3 | Minimum calls before calculating failure rate |
| `failureRateThreshold` | 50% | Opens circuit when failure rate exceeds this |
| `waitDurationInOpenState` | 10s | Time before transitioning from OPEN to HALF_OPEN |
| `permittedNumberOfCallsInHalfOpenState` | 2 | Test calls allowed in HALF_OPEN state |
| `retryMaxAttempts` | 3 | Retry count before giving up |
| `retryWaitDuration` | 1s | Wait between retries |

**Example: Testing the circuit breaker fallback**

```bash
# Normal response (circuit CLOSED)
curl http://localhost:30080/api/gateway/products
# Returns: [{"id":1,"name":"Laptop",...}, ...]

# Check circuit breaker state
curl http://localhost:30080/api/gateway/circuit-status | jq
# Shows: state=CLOSED, failureRate=0.0

# If product-service is down, after 3 failed calls (50% of 5):
# Returns fallback: [{"id":0,"name":"Service Temporarily Unavailable",...}]
# Circuit state changes to OPEN
```

---

## CI/CD Pipeline Details

### Individual Service Pipelines

Each service has its own Jenkinsfile (`jenkins/Jenkinsfile-{service-name}`) with 6 stages:

```
Checkout --> Build --> Test --> Docker Build --> Docker Push --> Deploy to K8s
```

| Stage | Command | Description |
|-------|---------|-------------|
| Checkout | `checkout scm` | Pull latest code |
| Build | `mvn clean package -DskipTests` | Compile and package the JAR |
| Test | `mvn test` | Run unit tests |
| Docker Build | `docker build -t localhost:5001/{service}:{BUILD_NUMBER}` | Build image with build number tag + latest |
| Docker Push | `docker push localhost:5001/{service}:{tag}` | Push both tagged and latest to local registry |
| Deploy to K8s | `kubectl set image deployment/{service}...` | Rolling update + rollout status check |

### Full Pipeline (Jenkinsfile-full-pipeline)

Builds, tests, and deploys all 3 services in a single pipeline run with parallelization:

```
Checkout
    │
    ▼
Build All (parallel)                    Test All (parallel)
┌─────────────────────┐                ┌─────────────────────┐
│ product-service     │                │ product-service     │
│ order-service       │ ──────────▶    │ order-service       │
│ api-gateway         │                │ api-gateway         │
└─────────────────────┘                └─────────────────────┘
                                                │
                                                ▼
                                       Docker Build & Push
                                       (all 3 services)
                                                │
                                                ▼
                                       Deploy to K8s
                                       (sequential: product → order → gateway)
                                                │
                                                ▼
                                       Integration Test
                                       (health endpoint verification)
```

### Setting Up Jenkins

1. Access Jenkins at `http://localhost:30000`
2. Get the initial admin password:
   ```bash
   kubectl exec -n jenkins $(kubectl get pod -n jenkins -l app=jenkins -o jsonpath='{.items[0].metadata.name}') \
     -- cat /var/jenkins_home/secrets/initialAdminPassword
   ```
3. Install suggested plugins
4. Create pipeline jobs pointing to the Jenkinsfile of your choice
5. Pipelines use `localhost:5001` as the Docker registry and deploy to the `microservices` namespace

---

## Monitoring Setup

### Deploy the Monitoring Stack (Kubernetes)

```bash
bash monitoring/setup-monitoring.sh
```

This deploys:
- **Prometheus** (NodePort 30090) -- Scrapes metrics from all 3 services every 5 seconds
- **Grafana** (NodePort 30030) -- Pre-configured with Prometheus datasource and a "Microservices Monitor" dashboard

### Access

| Tool | URL | Credentials |
|------|-----|-------------|
| Prometheus | http://localhost:30090 | None |
| Grafana | http://localhost:30030 | admin / admin |

### Pre-built Grafana Dashboard: "Microservices Monitor"

The dashboard includes 6 panels:

| Panel | Metric | What It Shows |
|-------|--------|---------------|
| **HTTP Request Rate** | `rate(http_server_requests_seconds_count[1m])` | Requests per second per service/endpoint |
| **HTTP Average Response Time** | `rate(sum/count)[1m] * 1000` | Average latency in milliseconds |
| **HTTP 5xx Error Rate** | `rate(http_server_requests_seconds_count{status=~"5.."}[1m])` | Server error rate per service |
| **JVM Memory Usage** | `sum(jvm_memory_used_bytes) by (area)` | Heap and non-heap memory per service |
| **Active Threads** | `jvm_threads_live_threads` | Live thread count per service |
| **Pod Up/Down Status** | `up{job="..."}` | Binary UP/DOWN indicator per service |

### Key Prometheus Queries

```promql
# Request rate per service
rate(http_server_requests_seconds_count{application="product-service"}[1m])

# 95th percentile response time
histogram_quantile(0.95, rate(http_server_requests_seconds_bucket{application="api-gateway"}[5m]))

# Error rate
rate(http_server_requests_seconds_count{status=~"5.."}[1m])

# JVM heap usage
sum(jvm_memory_used_bytes{area="heap"}) by (application)

# Circuit breaker state (via actuator metrics)
resilience4j_circuitbreaker_state{name="productService"}
```

---

## Chaos Engineering Experiments

### Overview

Chaos experiments use [Chaos Mesh](https://chaos-mesh.org/) to inject controlled failures into the Kubernetes environment. Each experiment tests a specific failure mode and validates that the system degrades gracefully.

### Install Chaos Mesh

```bash
bash chaos/install-chaos-mesh.sh
```

This installs Chaos Mesh v2.7.0 via Helm with Kind-compatible settings (containerd runtime).

### Access Chaos Mesh Dashboard

```bash
kubectl port-forward -n chaos-mesh svc/chaos-dashboard 2333:2333
# Open: http://localhost:2333
```

### Experiment Catalog

| # | Experiment | File | Type | Target | Duration | What It Tests |
|---|-----------|------|------|--------|----------|---------------|
| 1 | **Pod Kill - Product Service** | `pod-kill-product.yaml` | PodChaos | product-service (1 pod) | 30s (every 2m) | K8s self-healing, circuit breaker activation, fallback responses |
| 2 | **Pod Kill - Order Service** | `pod-kill-order.yaml` | PodChaos | order-service (1 pod) | 30s (every 2m) | Order service recovery, gateway fallback behavior |
| 3 | **Network Delay** | `network-delay.yaml` | NetworkChaos | product-service (all pods) | 60s | 500ms latency + 100ms jitter; tests timeout handling and retry behavior |
| 4 | **Network Partition** | `network-partition.yaml` | NetworkChaos | api-gateway <--> order-service | 30s | Complete network partition between gateway and orders; circuit breaker opens |
| 5 | **CPU Stress** | `cpu-stress.yaml` | StressChaos | order-service (all pods) | 60s | 80% CPU load with 2 workers; tests performance degradation under resource pressure |
| 6 | **Pod Failure** | `pod-failure.yaml` | PodChaos | api-gateway (1 pod) | 30s | Gateway pod made unavailable; tests K8s service routing to healthy replica |
| 7 | **HTTP Chaos (500 errors)** | `http-chaos.yaml` | HTTPChaos | product-service :8081 `/api/products` GET | 30s | Injects HTTP 500 responses; tests circuit breaker threshold and fallback |

### Running Experiments

**Run all experiments sequentially (with observation pauses):**

```bash
# Terminal 1: Start the observer (monitors health continuously)
bash chaos/observe.sh

# Terminal 2: Start continuous load (generates background traffic)
bash loadtest/continuous-load.sh

# Terminal 3: Run all chaos experiments
bash chaos/run-all-experiments.sh
```

**Run a single experiment:**

```bash
# Verify steady state first
bash chaos/steady-state-test.sh

# Apply the experiment
kubectl apply -f chaos/experiments/network-delay.yaml

# Watch the impact
watch kubectl get pods -n microservices
curl http://localhost:30080/api/gateway/circuit-status | jq

# Clean up the experiment
kubectl delete -f chaos/experiments/network-delay.yaml

# Verify recovery
bash chaos/steady-state-test.sh
```

### Chaos Engineering Workflow

The recommended workflow for each experiment follows the scientific method:

1. **Steady State** -- Run `bash chaos/steady-state-test.sh` to confirm all services return HTTP 200 and all pods are running
2. **Hypothesis** -- Predict what will happen (e.g., "If we kill a product-service pod, the circuit breaker will open and return fallback data within 10 seconds")
3. **Inject Failure** -- Apply the chaos experiment YAML
4. **Observe** -- Monitor via `observe.sh`, Grafana dashboard, and circuit breaker status endpoint
5. **Analyze** -- Compare actual behavior to hypothesis
6. **Clean Up** -- Delete the experiment and verify full recovery

---

## Load Testing

Three load generation scripts are provided for different scenarios:

### generate-load.sh -- Full Load Test

Generates realistic mixed traffic with configurable duration and requests-per-second.

```bash
# Default: 60 seconds at 5 req/s
bash loadtest/generate-load.sh

# Custom: 120 seconds at 10 req/s
bash loadtest/generate-load.sh 120 10
```

Traffic distribution: 40% GET products, 30% GET orders, 20% POST orders (triggers inter-service calls), 10% health checks.

### continuous-load.sh -- Background Load

Lightweight continuous load generator. Run during chaos experiments to observe the impact on real traffic.

```bash
# Default: 2 req/s (runs until Ctrl+C)
bash loadtest/continuous-load.sh

# Custom: 5 req/s
bash loadtest/continuous-load.sh 5
```

### spike-test.sh -- Traffic Spike

Three-phase test that simulates a traffic spike:

```bash
bash loadtest/spike-test.sh
```

| Phase | Duration | Rate | Purpose |
|-------|----------|------|---------|
| Normal | 15s | 2 req/s | Establish baseline |
| Spike | 10s | 20 req/s | Stress test |
| Cool down | 15s | 2 req/s | Verify recovery |

---

## Key Concepts Covered

This demo project serves as a comprehensive teaching tool for the following DevOps and cloud-native concepts:

### Microservices Architecture
- Service decomposition (product catalog, order management, API gateway)
- Inter-service communication via REST (synchronous HTTP calls)
- API gateway pattern as a single entry point
- Service discovery via Kubernetes DNS (service names resolve to ClusterIPs)
- Graceful degradation when downstream services are unavailable

### Containerization & Docker
- Multi-stage Docker builds (Maven build stage + JRE runtime stage)
- Docker Compose for local multi-service development
- Local Docker registry for Kubernetes image pulls
- Health checks in Docker Compose configuration
- Container networking (bridge network, service-to-service DNS)

### Kubernetes Orchestration
- Deployments with replica sets (2 replicas per service for high availability)
- Services: ClusterIP (internal) and NodePort (external access)
- Namespaces for resource isolation (microservices, jenkins, monitoring, chaos-mesh)
- Liveness and readiness probes for automated health management
- Resource requests and limits (CPU, memory)
- Rolling update deployments
- Kind for local Kubernetes development

### CI/CD Pipelines
- Jenkins declarative pipelines (Jenkinsfile)
- Parallel build and test stages for faster feedback
- Docker image tagging strategy (build number + latest)
- Automated deployment to Kubernetes with rollout verification
- Post-build integration testing
- Individual vs. monorepo pipeline strategies

### Fault Tolerance & Resilience
- Circuit breaker pattern (Resilience4j) with CLOSED/OPEN/HALF_OPEN states
- Automatic retry with configurable attempts and backoff
- Fallback responses when services are unavailable
- Sliding window failure rate calculation
- Health indicator integration with Spring Boot Actuator

### Observability & Monitoring
- Metrics collection with Micrometer + Prometheus
- Grafana dashboards for visualization
- Key metrics: request rate, latency, error rate, JVM memory, thread count
- Spring Boot Actuator endpoints (health, info, prometheus, metrics)
- Service up/down monitoring

### Chaos Engineering
- Chaos Mesh for Kubernetes-native fault injection
- Pod chaos: kill and failure experiments
- Network chaos: latency injection and partition
- Stress chaos: CPU resource pressure
- HTTP chaos: injecting error status codes
- Steady state hypothesis validation
- Observability during failure injection

---

## Useful Commands Quick Reference

### Kubernetes Commands

| Command | Description |
|---------|-------------|
| `kubectl get pods -n microservices` | List all microservice pods |
| `kubectl get pods -n microservices -w` | Watch pods in real-time |
| `kubectl get svc -n microservices` | List services and their ports |
| `kubectl get all -n microservices` | List all resources in namespace |
| `kubectl logs -f deployment/product-service -n microservices` | Stream product-service logs |
| `kubectl logs -f deployment/order-service -n microservices` | Stream order-service logs |
| `kubectl logs -f deployment/api-gateway -n microservices` | Stream api-gateway logs |
| `kubectl describe pod <pod-name> -n microservices` | Detailed pod information |
| `kubectl rollout restart deployment/product-service -n microservices` | Restart a deployment |
| `kubectl scale deployment/product-service --replicas=3 -n microservices` | Scale to 3 replicas |
| `kubectl get events -n microservices --sort-by=.lastTimestamp` | Recent cluster events |
| `kubectl top pods -n microservices` | Pod CPU/memory usage (requires metrics-server) |

### Docker Commands

| Command | Description |
|---------|-------------|
| `docker-compose up -d --build` | Build and start all services locally |
| `docker-compose down` | Stop and remove all containers |
| `docker-compose ps` | Show container status |
| `docker-compose logs -f api-gateway` | Stream gateway logs |
| `bash build-images.sh` | Build and push all images to local registry |
| `bash build-images.sh v2` | Build with custom tag |

### API Testing with curl

| Command | Description |
|---------|-------------|
| `curl http://localhost:30080/api/gateway/health \| jq` | Gateway health (K8s) |
| `curl http://localhost:30080/api/gateway/products \| jq` | List products via gateway (K8s) |
| `curl http://localhost:30080/api/gateway/orders \| jq` | List orders via gateway (K8s) |
| `curl http://localhost:30080/api/gateway/circuit-status \| jq` | Circuit breaker state (K8s) |
| `curl -X POST http://localhost:30080/api/gateway/orders -H "Content-Type: application/json" -d '{"productId":1,"quantity":2}'` | Create order via gateway (K8s) |
| `curl http://localhost:8080/api/gateway/products` | List products (Docker Compose) |

### Chaos Mesh Commands

| Command | Description |
|---------|-------------|
| `kubectl get podchaos,networkchaos,stresschaos,httpchaos -n microservices` | List active experiments |
| `kubectl delete podchaos --all -n microservices` | Stop all pod chaos experiments |
| `kubectl delete networkchaos --all -n microservices` | Stop all network chaos experiments |
| `kubectl delete stresschaos --all -n microservices` | Stop all stress chaos experiments |
| `kubectl delete httpchaos --all -n microservices` | Stop all HTTP chaos experiments |
| `kubectl port-forward -n chaos-mesh svc/chaos-dashboard 2333:2333` | Open Chaos Mesh dashboard |

### Jenkins Commands

| Command | Description |
|---------|-------------|
| `kubectl get pods -n jenkins` | Check Jenkins pod status |
| `kubectl exec -n jenkins $(kubectl get pod -n jenkins -l app=jenkins -o jsonpath='{.items[0].metadata.name}') -- cat /var/jenkins_home/secrets/initialAdminPassword` | Get initial admin password |
| `kubectl logs -f deployment/jenkins -n jenkins` | Stream Jenkins logs |

---

## Access Points Summary

### Kubernetes Mode (Kind)

| Service | URL | NodePort | Namespace |
|---------|-----|----------|-----------|
| **API Gateway** | http://localhost:30080 | 30080 | microservices |
| Products via Gateway | http://localhost:30080/api/gateway/products | 30080 | microservices |
| Orders via Gateway | http://localhost:30080/api/gateway/orders | 30080 | microservices |
| Circuit Breaker Status | http://localhost:30080/api/gateway/circuit-status | 30080 | microservices |
| **Jenkins** | http://localhost:30000 | 30000 | jenkins |
| **Prometheus** | http://localhost:30090 | 30090 | monitoring |
| **Grafana** | http://localhost:30030 | 30030 | monitoring |
| **Chaos Mesh Dashboard** | http://localhost:2333 (port-forward) | -- | chaos-mesh |
| **Docker Registry** | http://localhost:5001 | -- | -- |

### Docker Compose Mode

| Service | URL | Port |
|---------|-----|------|
| **API Gateway** | http://localhost:8080 | 8080 |
| Product Service (direct) | http://localhost:8081/api/products | 8081 |
| Order Service (direct) | http://localhost:8082/api/orders | 8082 |
| **Prometheus** | http://localhost:9090 | 9090 |
| **Grafana** | http://localhost:3000 (admin/admin) | 3000 |

---

## Troubleshooting

### Pods stuck in ImagePullBackOff

The local registry may not be connected to the Kind network:

```bash
docker network connect kind kind-registry
```

### Pods stuck in CrashLoopBackOff

Check the logs for startup errors:

```bash
kubectl logs <pod-name> -n microservices --previous
```

Common cause: JVM needs time to start. The liveness probe has a 60s initial delay to account for this.

### Cannot reach NodePort services

Verify the Kind cluster is running and port mappings are configured:

```bash
kind get clusters
docker ps | grep kindest
```

### Jenkins shows "Offline" or won't start

Jenkins requires significant memory. Check if the pod has enough resources:

```bash
kubectl describe pod -n jenkins -l app=jenkins
```

### Chaos Mesh experiments have no effect

Ensure Chaos Mesh is installed and all pods are running:

```bash
kubectl get pods -n chaos-mesh
```

Verify the target labels match your service deployments:

```bash
kubectl get pods -n microservices --show-labels
```

---

## Cleanup

### Remove everything (Kind cluster + registry)

```bash
bash teardown.sh
```

This deletes the Kind cluster (`microservices-demo`) and removes the local Docker registry container.

### Remove only Docker Compose resources

```bash
docker-compose down
```

### Remove only chaos experiments (keep cluster running)

```bash
kubectl delete podchaos,networkchaos,stresschaos,httpchaos --all -n microservices
```

### Remove only monitoring stack (keep cluster running)

```bash
kubectl delete namespace monitoring
```

### Remove only Chaos Mesh (keep cluster running)

```bash
helm uninstall chaos-mesh -n chaos-mesh
kubectl delete namespace chaos-mesh
```

---

## License

This project is intended for educational and training purposes.
