# Microservices CI/CD Pipeline & Chaos Engineering - Hands-On Lab Guide

> **Session:** Final Capstone Lab | **Duration:** ~2 hours | **Level:** Intermediate
>
> **Instructor Note:** This guide is designed for trainers delivering the final session of a microservices training program. Students should already be familiar with basic Docker, Kubernetes, and Java/Spring Boot concepts from prior sessions. This lab ties everything together into an end-to-end workflow.

---

## Table of Contents

1. [Lab Overview & Architecture](#1-lab-overview--architecture)
2. [Prerequisites](#2-prerequisites)
3. [Lab 1: Understanding the Microservices (15 min)](#3-lab-1-understanding-the-microservices-15-min)
4. [Lab 2: Containerization with Docker (10 min)](#4-lab-2-containerization-with-docker-10-min)
5. [Lab 3: Kubernetes Orchestration with Kind (20 min)](#5-lab-3-kubernetes-orchestration-with-kind-20-min)
6. [Lab 4: CI/CD Pipeline with Jenkins (15 min)](#6-lab-4-cicd-pipeline-with-jenkins-15-min)
7. [Lab 5: Monitoring with Prometheus & Grafana (15 min)](#7-lab-5-monitoring-with-prometheus--grafana-15-min)
8. [Lab 6: Chaos Engineering with Chaos Mesh (25 min)](#8-lab-6-chaos-engineering-with-chaos-mesh-25-min)
9. [Lab 7: Putting It All Together (10 min)](#9-lab-7-putting-it-all-together-10-min)
10. [Troubleshooting Guide](#10-troubleshooting-guide)
11. [Key Takeaways & Best Practices](#11-key-takeaways--best-practices)

---

## 1. Lab Overview & Architecture

### Architecture Diagram

```
                              +---------------------------------------------+
                              |          Kind Kubernetes Cluster             |
                              |                                             |
  +--------+                  |  +--- namespace: microservices -----------+  |
  |        |   :30080         |  |                                       |  |
  | Client |----------------->|  |  +--------------+                     |  |
  |  (curl |                  |  |  | api-gateway  |  (2 replicas)       |  |
  |  /     |                  |  |  |   :8080      |                     |  |
  | browser)                  |  |  +------+-------+                     |  |
  +--------+                  |  |         |                             |  |
                              |  |    +----+--------+                    |  |
                              |  |    |             |                    |  |
                              |  |    v             v                    |  |
                              |  | +----------+ +----------+            |  |
                              |  | | product- | | order-   |            |  |
                              |  | | service  | | service  |            |  |
                              |  | | :8081    | | :8082    |            |  |
                              |  | |(2 repli.)| |(2 repli.)|            |  |
                              |  | +----------+ +-----+----+            |  |
                              |  |                     |                 |  |
                              |  |                     | (REST call:     |  |
                              |  |                     |  validate       |  |
                              |  |                     |  product &      |  |
                              |  |                     |  get price)     |  |
                              |  |                     v                 |  |
                              |  |               +----------+            |  |
                              |  |               | product- |            |  |
                              |  |               | service  |            |  |
                              |  |               +----------+            |  |
                              |  +---------------------------------------+  |
                              |                                             |
                              |  +--- namespace: jenkins ----------------+  |
  +--------+   :30000         |  |  +---------+                          |  |
  | Dev /  |----------------->|  |  | Jenkins | --> docker build/push    |  |
  | Admin  |                  |  |  | :8080   | --> kubectl deploy       |  |
  +--------+                  |  |  +---------+                          |  |
                              |  +---------------------------------------+  |
                              |                                             |
                              |  +--- namespace: monitoring -------------+  |
  +--------+   :30090         |  |  +------------+      scrape           |  |
  | Admin  |----------------->|  |  | Prometheus |----> /actuator/       |  |
  +--------+                  |  |  | :9090      |      prometheus       |  |
                              |  |  +-----+------+    (all 3 services)   |  |
  +--------+   :30030         |  |        |                              |  |
  | Admin  |----------------->|  |  +-----v------+                       |  |
  +--------+                  |  |  | Grafana    |                       |  |
                              |  |  | :3000      |                       |  |
                              |  |  +------------+                       |  |
                              |  +---------------------------------------+  |
                              |                                             |
                              |  +--- namespace: chaos-mesh -------------+  |
                              |  |  +-------------+   inject failures    |  |
                              |  |  | Chaos Mesh  |----> pods in         |  |
                              |  |  | Controller  |      microservices   |  |
                              |  |  +-------------+      namespace       |  |
                              |  +---------------------------------------+  |
                              |                                             |
                              +---------------------------------------------+
                                        |
                              +---------+----------+
                              | Local Docker       |
                              | Registry           |
                              | localhost:5001      |
                              +--------------------+
```

### Communication Flow

```
Request Flow:
  Client --> API Gateway (:30080) --> product-service (:8081)  [GET products]
  Client --> API Gateway (:30080) --> order-service (:8082)    [GET/POST orders]
                                       |
                                       +--> product-service (:8081)  [validate product, get price]

Monitoring Flow:
  Prometheus --> product-service /actuator/prometheus  (scrape every 5s)
  Prometheus --> order-service   /actuator/prometheus  (scrape every 5s)
  Prometheus --> api-gateway     /actuator/prometheus  (scrape every 5s)
  Grafana   --> Prometheus                             (query metrics)

CI/CD Flow:
  Code Change --> Jenkins (Build) --> Maven (Compile + Test)
             --> Docker (Build Image) --> Registry (Push localhost:5001)
             --> kubectl (Rolling Update) --> K8s (Deploy to microservices ns)

Chaos Flow:
  Chaos Mesh Controller --> Target pods (kill, delay, partition, stress)
  Observer              --> Grafana + kubectl (watch impact in real time)
```

### What You Will Learn

By completing this lab, students will gain hands-on experience with:

- **Microservices architecture** -- building, connecting, and managing independent services that communicate over REST APIs
- **Inter-service communication** -- how order-service calls product-service using RestTemplate, and what happens when that dependency is unavailable
- **Docker multi-stage builds** -- separating build-time and runtime environments to produce small, efficient container images
- **Kubernetes orchestration** -- deployments with replicas, services for discovery, readiness/liveness probes, and resource limits
- **CI/CD pipelines with Jenkins** -- declarative pipelines with parallel stages, automated build-test-deploy workflows
- **Observability with Prometheus & Grafana** -- metrics collection via Micrometer, PromQL queries, and pre-built dashboards
- **Chaos engineering** -- systematically injecting failures (pod kills, network delays, partitions, CPU stress) to validate system resilience

---

## 2. Prerequisites

### Required Software

Ensure the following tools are installed on your lab machine. The versions shown are minimums.

| Tool | Purpose | Minimum Version |
|------|---------|-----------------|
| Docker | Container runtime | 20.10+ |
| Kind | Local Kubernetes clusters | 0.20+ |
| kubectl | Kubernetes CLI | 1.27+ |
| Helm | Kubernetes package manager | 3.12+ |
| Java JDK | Build Spring Boot apps | 17 |
| Maven | Java build tool | 3.9+ |
| curl | HTTP testing | any |

### Installation Commands (Ubuntu/Debian)

```bash
# Docker
sudo apt-get update
sudo apt-get install -y docker.io
sudo usermod -aG docker $USER
# Log out and back in for group changes to take effect

# Kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/kubectl

# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Java 17
sudo apt-get install -y openjdk-17-jdk

# Maven
sudo apt-get install -y maven
```

### Verification Commands

> **Instructor Tip:** Have every student run these before proceeding. This catches environment issues early and saves time.

```bash
docker --version          # Docker version 20.10.x or higher
kind --version            # kind v0.20.0 or higher
kubectl version --client  # Client Version: v1.27.x or higher
helm version --short      # v3.12.x or higher
java -version             # openjdk version "17.x.x"
mvn -version              # Apache Maven 3.9.x or higher
curl --version            # curl 7.x or higher
```

---

## 3. Lab 1: Understanding the Microservices (15 min)

> **Instructor Note:** This lab builds conceptual understanding before we containerize and deploy. Walk students through the code and highlight the key design patterns. Ask students questions as you go -- "Why is this a separate service?" "What happens if product-service is down?"

### 1.1 Project Structure

Explore the demo directory to understand how the project is organized:

```bash
cd /home/azureuser/final-demo

# View top-level structure
ls -la
```

The project layout is:

```
final-demo/
|-- product-service/          # Microservice 1: Product catalog (port 8081)
|   |-- src/main/java/com/demo/product/
|   |   |-- ProductServiceApplication.java
|   |   |-- controller/ProductController.java
|   |   +-- model/Product.java
|   |-- src/main/resources/application.yml
|   |-- src/test/java/...
|   |-- Dockerfile
|   +-- pom.xml
|-- order-service/            # Microservice 2: Order management (port 8082)
|   |-- src/main/java/com/demo/order/
|   |   |-- OrderServiceApplication.java
|   |   |-- controller/OrderController.java
|   |   |-- model/Order.java
|   |   |-- dto/ProductDTO.java
|   |   +-- service/ProductServiceClient.java
|   |-- src/main/resources/application.yml
|   |-- src/test/java/...
|   |-- Dockerfile
|   +-- pom.xml
|-- api-gateway/              # Microservice 3: API Gateway (port 8080)
|   |-- src/main/java/com/demo/gateway/
|   |   |-- ApiGatewayApplication.java
|   |   +-- controller/GatewayController.java
|   |-- src/main/resources/application.yml
|   |-- Dockerfile
|   +-- pom.xml
|-- k8s/                      # Kubernetes manifests
|   |-- kind-config.yaml
|   |-- namespace.yaml
|   |-- product-service/      # deployment.yaml + service.yaml
|   |-- order-service/        # deployment.yaml + service.yaml
|   |-- api-gateway/          # deployment.yaml + service.yaml
|   |-- jenkins/              # deployment.yaml + service.yaml + rbac.yaml
|   +-- monitoring/           # prometheus + grafana configs
|-- jenkins/                  # Jenkinsfile definitions
|   |-- Jenkinsfile-product-service
|   |-- Jenkinsfile-order-service
|   |-- Jenkinsfile-api-gateway
|   +-- Jenkinsfile-full-pipeline
|-- chaos/                    # Chaos engineering
|   |-- experiments/          # YAML experiment definitions
|   |-- install-chaos-mesh.sh
|   |-- steady-state-test.sh
|   |-- observe.sh
|   +-- run-all-experiments.sh
|-- monitoring/
|   +-- setup-monitoring.sh
|-- setup.sh                  # One-command full setup
|-- build-images.sh           # Build & push all images
|-- deploy.sh                 # Deploy/update all services
|-- teardown.sh               # Destroy everything
+-- test-services.sh          # Health check all endpoints
```

### 1.2 Product Service Deep Dive

The product-service is the simplest microservice -- a stateless REST API that manages a product catalog.

**ProductController.java** -- the REST controller:

```java
@RestController
@RequestMapping("/api/products")
public class ProductController {

    private final List<Product> products = new ArrayList<>();
    private final AtomicLong idCounter = new AtomicLong(3);

    public ProductController() {
        // Pre-loaded sample data (in-memory, no database needed)
        products.add(new Product(1L, "Laptop", 999.99, "High-performance laptop with 16GB RAM"));
        products.add(new Product(2L, "Wireless Mouse", 29.99, "Ergonomic wireless mouse with USB receiver"));
        products.add(new Product(3L, "Mechanical Keyboard", 79.99, "RGB mechanical keyboard with Cherry MX switches"));
    }

    @GetMapping
    public ResponseEntity<List<Product>> getAllProducts() { ... }

    @GetMapping("/{id}")
    public ResponseEntity<Product> getProductById(@PathVariable Long id) { ... }

    @PostMapping
    public ResponseEntity<Product> addProduct(@RequestBody Product product) { ... }

    @GetMapping("/health")
    public ResponseEntity<String> healthCheck() { ... }
}
```

> **Key points to discuss:**
> - In-memory data store (no database) -- keeps the demo simple and focused on architecture
> - `AtomicLong` for thread-safe ID generation
> - Standard REST conventions: GET for retrieval, POST for creation
> - Dedicated `/health` endpoint for monitoring

**Product.java** -- the data model:

```java
public class Product {
    private Long id;
    private String name;
    private Double price;
    private String description;
    // constructors, getters, setters
}
```

**application.yml** -- service configuration:

```yaml
server:
  port: 8081

spring:
  application:
    name: product-service

management:
  endpoints:
    web:
      exposure:
        include: health,info,prometheus,metrics
  metrics:
    export:
      prometheus:
        enabled: true
    tags:
      application: product-service
```

> **Key points to discuss:**
> - Port 8081 is the default; this can be overridden with environment variables in K8s
> - The `management` block exposes Spring Boot Actuator endpoints including `/actuator/prometheus` for Prometheus scraping
> - `micrometer-registry-prometheus` dependency (in pom.xml) enables automatic metric export
> - The `application` tag lets Prometheus/Grafana distinguish metrics from each service

### 1.3 Order Service Deep Dive

The order-service is more interesting because it demonstrates **inter-service communication**. When a new order is created, it calls product-service to validate the product and retrieve the current price.

**OrderController.java** -- the REST controller (pay special attention to `createOrder`):

```java
@PostMapping
public ResponseEntity<Order> createOrder(@RequestBody Order order) {
    order.setId(idCounter.getAndIncrement());
    if (order.getStatus() == null) {
        order.setStatus("PENDING");
    }

    // Call product-service to validate product and get price
    if (order.getProductId() != null) {
        ProductDTO product = productServiceClient.getProduct(order.getProductId());
        if (product != null) {
            order.setProductName(product.getName());
            order.setTotalPrice(product.getPrice() * order.getQuantity());
        } else {
            // Product-service unreachable or product not found -- graceful degradation
            if (order.getProductName() == null) {
                order.setProductName("Unknown (product-service unavailable)");
            }
            // Keep the provided totalPrice as-is
        }
    }

    orders.add(order);
    return ResponseEntity.status(HttpStatus.CREATED).body(order);
}
```

> **Instructor Tip:** This is one of the most important pieces to explain. Ask students: "What happens if product-service is down when we create an order?" The answer: the order still gets created, but with `"Unknown (product-service unavailable)"` as the product name. This is **graceful degradation** -- the system continues to function in a degraded mode rather than failing completely.

**ProductServiceClient.java** -- the inter-service communication layer:

```java
@Service
public class ProductServiceClient {

    private final RestTemplate restTemplate;

    @Value("${product.service.url:http://localhost:8081}")
    private String productServiceUrl;

    public ProductDTO getProduct(Long productId) {
        try {
            String url = productServiceUrl + "/api/products/" + productId;
            return restTemplate.getForObject(url, ProductDTO.class);
        } catch (Exception e) {
            System.out.println("Failed to reach product-service: " + e.getMessage());
            return null;  // Graceful fallback: return null instead of propagating exception
        }
    }

    public boolean isProductServiceHealthy() {
        try {
            String url = productServiceUrl + "/api/products/health";
            String response = restTemplate.getForObject(url, String.class);
            return response != null && response.contains("UP");
        } catch (Exception e) {
            return false;
        }
    }
}
```

> **Key points to discuss:**
> - `RestTemplate` is used for synchronous HTTP calls between services
> - The product-service URL is configurable via the `PRODUCT_SERVICE_URL` environment variable (critical for K8s deployment where service names are used for DNS-based discovery)
> - The `try/catch` block implements basic resilience -- if the call fails, the client returns `null` rather than throwing an exception up the call stack
> - The `isProductServiceHealthy()` method provides a way to check dependency health

**The order-service also exposes enriched endpoints:**

- `GET /api/orders/with-products` -- returns orders enriched with live product details from product-service, showing real-time inter-service integration
- `GET /api/orders/service-health` -- reports both order-service health AND product-service connectivity status

**application.yml** for order-service:

```yaml
server:
  port: 8082

spring:
  application:
    name: order-service

management:
  endpoints:
    web:
      exposure:
        include: health,info,prometheus,metrics
  metrics:
    export:
      prometheus:
        enabled: true
    tags:
      application: order-service

product:
  service:
    url: ${PRODUCT_SERVICE_URL:http://localhost:8081}
```

> **Key point:** The `${PRODUCT_SERVICE_URL:http://localhost:8081}` syntax means "use the `PRODUCT_SERVICE_URL` environment variable if set, otherwise fall back to `http://localhost:8081`." In Kubernetes, the deployment sets this to `http://product-service:8081` using K8s DNS-based service discovery.

### 1.4 API Gateway Deep Dive

The api-gateway provides a **single entry point** for all client requests, routing them to the appropriate backend service.

**GatewayController.java:**

```java
@RestController
@RequestMapping("/api/gateway")
public class GatewayController {

    @Value("${product.service.url}")
    private String productServiceUrl;

    @Value("${order.service.url}")
    private String orderServiceUrl;

    @GetMapping("/products")
    public ResponseEntity<Object> getProducts() {
        try {
            ResponseEntity<Object> response = restTemplate.getForEntity(
                productServiceUrl + "/api/products", Object.class);
            return ResponseEntity.ok(response.getBody());
        } catch (Exception e) {
            // Return a 503 with error details instead of crashing
            Map<String, Object> fallback = new HashMap<>();
            fallback.put("error", "Product service is unavailable");
            fallback.put("service", "product-service");
            fallback.put("timestamp", LocalDateTime.now().toString());
            return ResponseEntity.status(503).body(fallback);
        }
    }

    @GetMapping("/health")
    public ResponseEntity<Map<String, Object>> gatewayHealth() {
        // Aggregates health from gateway + product-service + order-service
        // Returns UP/DOWN status for each downstream service
    }
}
```

> **Key points to discuss:**
> - The API Gateway pattern gives clients a single URL to interact with
> - It handles errors from downstream services gracefully, returning structured 503 responses instead of raw stack traces
> - The `/health` endpoint aggregates health from ALL services -- this is a critical operational tool
> - In production, you would typically use Spring Cloud Gateway or an Envoy sidecar; this simplified implementation demonstrates the concept

### 1.5 Hands-on Exercise: Run Locally

> **Instructor Note:** This exercise requires two terminal windows. If time is tight, you can demonstrate this instead of having students do it. The key learning is seeing the inter-service communication in action.

**Terminal 1 -- Start product-service:**

```bash
cd /home/azureuser/final-demo/product-service
mvn spring-boot:run
```

Wait until you see `Started ProductServiceApplication` in the output.

**Terminal 2 -- Test product-service:**

```bash
# Get all products
curl -s http://localhost:8081/api/products | python3 -m json.tool

# Expected output: array of 3 products (Laptop, Wireless Mouse, Mechanical Keyboard)

# Get a single product
curl -s http://localhost:8081/api/products/1 | python3 -m json.tool

# Expected: {"id":1,"name":"Laptop","price":999.99,"description":"High-performance laptop with 16GB RAM"}
```

**Terminal 2 -- Start order-service (keep product-service running):**

Open a new terminal:

```bash
cd /home/azureuser/final-demo/order-service
mvn spring-boot:run
```

**Terminal 3 -- Test inter-service communication:**

```bash
# Create an order -- watch order-service call product-service!
curl -s -X POST http://localhost:8082/api/orders \
  -H "Content-Type: application/json" \
  -d '{"productId": 1, "quantity": 2}' | python3 -m json.tool
```

**Expected output:**

```json
{
    "id": 3,
    "productId": 1,
    "productName": "Laptop",
    "quantity": 2,
    "totalPrice": 1999.98,
    "status": "PENDING"
}
```

> **Discussion point:** Notice that we only sent `productId` and `quantity`. The order-service reached out to product-service, retrieved the product name ("Laptop") and price ($999.99), then calculated the total ($999.99 x 2 = $1999.98). This is inter-service communication in action.

**Test graceful degradation -- stop product-service (Ctrl+C in Terminal 1), then:**

```bash
curl -s -X POST http://localhost:8082/api/orders \
  -H "Content-Type: application/json" \
  -d '{"productId": 1, "quantity": 3}' | python3 -m json.tool
```

**Expected output:**

```json
{
    "id": 4,
    "productId": 1,
    "productName": "Unknown (product-service unavailable)",
    "quantity": 3,
    "totalPrice": null,
    "status": "PENDING"
}
```

> **Discussion point:** The order was still created! The system degraded gracefully -- it noted that the product service was unavailable but did not reject the order entirely. In a real system, this order could be enriched later when product-service comes back online.

**Clean up:** Stop all running services with Ctrl+C in each terminal.

---

## 4. Lab 2: Containerization with Docker (10 min)

### 2.1 Understanding the Dockerfile

All three services use the same multi-stage Dockerfile pattern. Let us examine the product-service Dockerfile:

```dockerfile
# Stage 1: Build the application
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline -B
COPY src ./src
RUN mvn clean package -DskipTests -B

# Stage 2: Run the application
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY --from=build /app/target/*.jar app.jar
EXPOSE 8081
ENTRYPOINT ["java", "-jar", "app.jar"]
```

**Line-by-line walkthrough:**

| Line | Purpose |
|------|---------|
| `FROM maven:3.9-eclipse-temurin-17 AS build` | Stage 1: Uses a full Maven+JDK image for building. The `AS build` names this stage so we can reference it later. |
| `WORKDIR /app` | Sets the working directory inside the container. |
| `COPY pom.xml .` | Copies only the POM file first (dependency caching optimization). |
| `RUN mvn dependency:go-offline -B` | Downloads all dependencies. This layer is cached by Docker -- if pom.xml has not changed, Docker skips this step on rebuild. This is the key optimization. |
| `COPY src ./src` | Copies the actual source code. |
| `RUN mvn clean package -DskipTests -B` | Builds the JAR file. Tests are skipped during Docker build (they run in the CI pipeline). |
| `FROM eclipse-temurin:17-jre-alpine` | Stage 2: Uses a minimal Alpine-based JRE image (no JDK, no Maven, no source code). |
| `COPY --from=build /app/target/*.jar app.jar` | Copies ONLY the built JAR from Stage 1. Everything else from the build stage is discarded. |
| `EXPOSE 8081` | Documents which port the service listens on. |
| `ENTRYPOINT ["java", "-jar", "app.jar"]` | The command that runs when the container starts. |

> **Instructor Tip:** Emphasize the size difference. The build stage image (maven:3.9-eclipse-temurin-17) is approximately 800MB. The final runtime image (eclipse-temurin:17-jre-alpine) is approximately 180MB. Multi-stage builds let us use heavy tools for building but ship only what is needed at runtime.

### 2.2 Building Docker Images

```bash
cd /home/azureuser/final-demo

# Build all three services
docker build -t product-service:v1 product-service/
docker build -t order-service:v1 order-service/
docker build -t api-gateway:v1 api-gateway/

# Verify the images were created
docker images | grep -E "product|order|gateway"
```

Expected output (sizes will be approximately 200-250MB each):

```
product-service   v1    abc123def456   10 seconds ago   215MB
order-service     v1    def456abc789   20 seconds ago   218MB
api-gateway       v1    789abc123def   30 seconds ago   212MB
```

### 2.3 Running with Docker Compose-Style Commands

Since these services need to communicate, we need Docker networking:

```bash
# Create a shared network
docker network create microservices-net

# Start product-service
docker run -d --name product-service \
  --network microservices-net \
  -p 8081:8081 \
  product-service:v1

# Start order-service (note: PRODUCT_SERVICE_URL uses the container name for DNS)
docker run -d --name order-service \
  --network microservices-net \
  -p 8082:8082 \
  -e PRODUCT_SERVICE_URL=http://product-service:8081 \
  order-service:v1

# Start api-gateway (needs URLs for both backend services)
docker run -d --name api-gateway \
  --network microservices-net \
  -p 8080:8080 \
  -e PRODUCT_SERVICE_URL=http://product-service:8081 \
  -e ORDER_SERVICE_URL=http://order-service:8082 \
  api-gateway:v1
```

**Test the containerized services:**

```bash
# Wait about 15 seconds for Spring Boot to start, then:
curl -s http://localhost:8080/api/gateway/health | python3 -m json.tool
curl -s http://localhost:8080/api/gateway/products | python3 -m json.tool
curl -s -X POST http://localhost:8082/api/orders \
  -H "Content-Type: application/json" \
  -d '{"productId": 2, "quantity": 5}' | python3 -m json.tool
```

**Clean up:**

```bash
docker rm -f product-service order-service api-gateway
docker network rm microservices-net
```

### 2.4 Key Concepts

> **Concepts to reinforce with students:**
>
> - **Multi-stage builds** reduce final image size by 70-80% -- only the JAR and JRE ship in the final image
> - **Dependency caching** (`mvn dependency:go-offline` before `COPY src`) makes rebuilds fast when only source code changes
> - **Environment variables** (`-e PRODUCT_SERVICE_URL=...`) allow the same image to run in different environments (local, Docker, K8s) with different configurations
> - **Docker networking** provides DNS-based service discovery: containers on the same network can reach each other by container name

---

## 5. Lab 3: Kubernetes Orchestration with Kind (20 min)

### 3.1 Setting Up the Kind Cluster

> **Instructor Note:** If the cluster is already running from pre-lab setup, skip to Section 3.2. The `setup.sh` script is idempotent -- it will skip steps that are already completed.

**Understanding the Kind configuration (`k8s/kind-config.yaml`):**

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
      - containerPort: 443
        hostPort: 443
      - containerPort: 30000
        hostPort: 30000
  - role: worker
containerdConfigPatches:
  - |-
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:5001"]
      endpoint = ["http://kind-registry:5001"]
```

> **Key points to discuss:**
> - Two nodes: one control-plane and one worker (simulates a real cluster)
> - `extraPortMappings` maps container ports to host ports so we can access NodePort services from localhost
> - The `containerdConfigPatches` section configures Kind to pull images from our local Docker registry (`localhost:5001`) instead of Docker Hub

**Run the full setup:**

```bash
cd /home/azureuser/final-demo
bash setup.sh
```

**What `setup.sh` does step by step:**

1. **Checks prerequisites** -- verifies docker, kind, kubectl, helm are installed
2. **Creates a local Docker registry** -- `docker run -d --name kind-registry -p 5001:5000 registry:2`
3. **Creates the Kind cluster** -- `kind create cluster --config k8s/kind-config.yaml`
4. **Connects the registry to Kind's network** -- so K8s nodes can pull images from `localhost:5001`
5. **Creates namespaces** -- `microservices` and `jenkins`
6. **Builds and pushes Docker images** -- builds all three services and pushes to `localhost:5001`
7. **Deploys microservices** -- applies deployment and service manifests
8. **Deploys Jenkins** -- applies Jenkins deployment, service, and RBAC manifests
9. **Installs NGINX Ingress Controller** -- for HTTP routing (optional)
10. **Waits for rollouts** -- confirms all deployments are ready

### 3.2 Understanding K8s Manifests

**Product Service Deployment (`k8s/product-service/deployment.yaml`):**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: product-service
  namespace: microservices
spec:
  replicas: 2                          # High availability: 2 instances
  selector:
    matchLabels:
      app: product-service
  template:
    spec:
      containers:
        - name: product-service
          image: localhost:5001/product-service:latest
          ports:
            - containerPort: 8081
          readinessProbe:              # "Is this pod ready to receive traffic?"
            httpGet:
              path: /actuator/health
              port: 8081
            initialDelaySeconds: 30    # Wait 30s before first check (Spring Boot startup)
            periodSeconds: 10          # Check every 10s
            timeoutSeconds: 5          # Timeout after 5s
            failureThreshold: 3        # 3 failures = mark as not ready
          livenessProbe:               # "Is this pod still alive?"
            httpGet:
              path: /actuator/health
              port: 8081
            initialDelaySeconds: 60    # Wait 60s (longer than readiness)
            periodSeconds: 15          # Check every 15s
            failureThreshold: 3        # 3 failures = restart the pod
          resources:
            requests:                  # Minimum resources guaranteed
              cpu: 250m                # 0.25 CPU cores
              memory: 256Mi            # 256 MB RAM
            limits:                    # Maximum resources allowed
              cpu: 500m                # 0.5 CPU cores
              memory: 512Mi            # 512 MB RAM
```

> **Important distinction to teach -- Readiness vs. Liveness probes:**
>
> | Probe | Question It Answers | What Happens on Failure |
> |-------|---------------------|------------------------|
> | **Readiness** | "Can this pod handle requests right now?" | Pod is removed from Service endpoints (no traffic routed to it) but pod keeps running |
> | **Liveness** | "Is this pod still functioning?" | Pod is killed and restarted by K8s |
>
> A pod that fails readiness checks stays alive but receives no traffic -- useful during startup or temporary overload. A pod that fails liveness checks is restarted entirely -- useful for recovering from deadlocks or memory leaks.

**Order Service Deployment** -- same structure but with an environment variable:

```yaml
env:
  - name: PRODUCT_SERVICE_URL
    value: "http://product-service:8081"   # K8s DNS-based service discovery!
```

> **Key point:** In Kubernetes, services get DNS names automatically. The format is `<service-name>.<namespace>.svc.cluster.local`. Since both services are in the `microservices` namespace, the short form `product-service` is sufficient. This replaces Docker's container-name-based DNS.

**Service types explained:**

```yaml
# product-service and order-service: ClusterIP (internal only)
spec:
  type: ClusterIP     # Only reachable from INSIDE the cluster
  ports:
    - port: 8081
      targetPort: 8081

# api-gateway: NodePort (externally accessible)
spec:
  type: NodePort       # Reachable from OUTSIDE the cluster
  ports:
    - port: 8080
      targetPort: 8080
      nodePort: 30080  # Accessible at localhost:30080
```

> **Instructor Tip:** Draw this on the whiteboard: "ClusterIP = internal phone extension, NodePort = external phone number." Product-service and order-service are internal -- only other services in the cluster can reach them. The api-gateway is the front door exposed to the outside world.

### 3.3 Verifying the Deployment

```bash
# See all resources in the microservices namespace
kubectl get all -n microservices

# Expected output: 3 deployments, 3 replicasets, 6 pods (2 per service), 3 services

# Detailed view of a specific deployment
kubectl describe deployment product-service -n microservices

# Check pod logs (follow mode)
kubectl logs -f deployment/order-service -n microservices

# Check pod resource usage
kubectl top pods -n microservices
```

### 3.4 Testing Inter-Service Communication in K8s

```bash
# Health check -- shows gateway status plus status of both downstream services
curl -s http://localhost:30080/api/gateway/health | python3 -m json.tool

# Get products via the gateway
curl -s http://localhost:30080/api/gateway/products | python3 -m json.tool

# Get orders via the gateway
curl -s http://localhost:30080/api/gateway/orders | python3 -m json.tool

# Create an order via the gateway -- this triggers the full chain:
# Client -> api-gateway -> order-service -> product-service (for price) -> response back
curl -s -X POST http://localhost:30080/api/gateway/orders \
  -H "Content-Type: application/json" \
  -d '{"productId": 3, "quantity": 2}' | python3 -m json.tool
```

> **Instructor Tip:** After the POST request, highlight that the response includes `"productName": "Mechanical Keyboard"` and `"totalPrice": 159.98` -- proving that order-service successfully called product-service inside the K8s cluster using DNS-based service discovery.

### 3.5 Scaling Exercise

```bash
# Scale product-service from 2 to 3 replicas
kubectl scale deployment product-service --replicas=3 -n microservices

# Watch pods come up in real-time
kubectl get pods -n microservices -w

# Verify -- you should now see 3 product-service pods
kubectl get pods -n microservices -l app=product-service
```

> **Discussion point:** K8s automatically load-balances traffic across all 3 replicas. The Service object acts as a load balancer. No client-side changes are needed -- the clients still use `http://product-service:8081` and K8s routes the request to a healthy pod.

**Scale back:**

```bash
kubectl scale deployment product-service --replicas=2 -n microservices
```

### 3.6 Key Concepts

> **Concepts to reinforce with students:**
>
> - **Self-healing:** If a pod crashes, K8s automatically restarts it. If a node fails, pods are rescheduled to other nodes.
> - **Service discovery via DNS:** No need for hardcoded IPs or external service registries. K8s DNS resolves service names to pod IPs automatically.
> - **Rolling updates:** When deploying a new image, K8s replaces pods one at a time, maintaining availability throughout the update. Zero-downtime deployments out of the box.
> - **Resource management:** Requests guarantee minimum resources; limits prevent runaway containers from affecting neighbors.

---

## 6. Lab 4: CI/CD Pipeline with Jenkins (15 min)

### 4.1 Accessing Jenkins

```bash
# Get the Jenkins initial admin password
kubectl exec -n jenkins \
  $(kubectl get pod -n jenkins -l app=jenkins -o jsonpath='{.items[0].metadata.name}') \
  -- cat /var/jenkins_home/secrets/initialAdminPassword
```

Open http://localhost:30000 in your browser and enter the password.

> **Instructor Note:** Jenkins initial setup takes several minutes. If Jenkins is not ready yet, proceed to Section 4.2 and 4.3 which cover the Jenkinsfile structure and manual pipeline simulation. Jenkins can be explored when it becomes available.

### 4.2 Understanding the Jenkinsfiles

**Individual Service Pipeline (`jenkins/Jenkinsfile-product-service`):**

```groovy
pipeline {
    agent any

    environment {
        REGISTRY = 'localhost:5001'
        IMAGE    = 'product-service'
        TAG      = "${BUILD_NUMBER}"        // Each build gets a unique tag
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm                 // Pull latest code from Git
            }
        }

        stage('Build') {
            steps {
                sh 'cd product-service && mvn clean package -DskipTests'
            }
        }

        stage('Test') {
            steps {
                sh 'cd product-service && mvn test'     // Run unit tests
            }
        }

        stage('Docker Build') {
            steps {
                sh "docker build -t ${REGISTRY}/${IMAGE}:${TAG} -t ${REGISTRY}/${IMAGE}:latest product-service/"
            }
        }

        stage('Docker Push') {
            steps {
                sh "docker push ${REGISTRY}/${IMAGE}:${TAG}"
                sh "docker push ${REGISTRY}/${IMAGE}:latest"
            }
        }

        stage('Deploy to K8s') {
            steps {
                sh "kubectl set image deployment/${IMAGE} ${IMAGE}=${REGISTRY}/${IMAGE}:${TAG} -n microservices"
                sh "kubectl rollout status deployment/${IMAGE} -n microservices --timeout=120s"
            }
        }
    }

    post {
        success { echo 'Pipeline succeeded!' }
        failure { echo 'Pipeline failed!' }
    }
}
```

**Pipeline flow:**

```
+----------+     +-------+     +------+     +--------------+     +-------------+     +-------------+
| Checkout | --> | Build | --> | Test | --> | Docker Build | --> | Docker Push | --> | Deploy K8s  |
+----------+     +-------+     +------+     +--------------+     +-------------+     +-------------+
```

**Full Pipeline (`jenkins/Jenkinsfile-full-pipeline`)** -- builds ALL services with parallel stages:

```groovy
stage('Build All') {
    parallel {                                 // Three builds run simultaneously!
        stage('Build product-service') {
            steps { sh 'cd product-service && mvn clean package -DskipTests' }
        }
        stage('Build order-service') {
            steps { sh 'cd order-service && mvn clean package -DskipTests' }
        }
        stage('Build api-gateway') {
            steps { sh 'cd api-gateway && mvn clean package -DskipTests' }
        }
    }
}

stage('Test All') {
    parallel {                                 // Three test suites run simultaneously!
        stage('Test product-service') { ... }
        stage('Test order-service') { ... }
        stage('Test api-gateway') { ... }
    }
}

stage('Integration Test') {
    steps {
        sh '''
            sleep 10
            RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:30080/actuator/health)
            if [ "$RESPONSE" = "200" ]; then
                echo "Integration test PASSED"
            else
                echo "Integration test FAILED"
                exit 1
            fi
        '''
    }
}
```

**Full pipeline flow:**

```
              +-- Build product-service --+     +-- Test product-service --+
              |                           |     |                          |
Checkout ---> +-- Build order-service   --+--> +-- Test order-service   --+--> Docker Build & Push --> Deploy --> Integration Test
              |                           |     |                          |
              +-- Build api-gateway     --+     +-- Test api-gateway     --+
                   (parallel)                        (parallel)
```

> **Key points to discuss:**
> - **Declarative pipeline syntax** -- structured, readable, easy to maintain
> - **Parallel stages** -- Build and Test stages run all three services concurrently, significantly reducing pipeline time
> - **Build number as tag** -- `${BUILD_NUMBER}` gives each image a unique, traceable version. You can always roll back to a specific build.
> - **Integration test** -- the final stage verifies the deployment actually works before declaring success

### 4.3 Simulating a CI/CD Pipeline Manually

> **Instructor Tip:** Since configuring Jenkins with Git credentials and pipeline jobs takes time, this section walks through the exact same steps the pipeline performs, executed manually from the command line. This is also a great way to understand what each stage does.

```bash
cd /home/azureuser/final-demo

# --------------------------------------------------
# Stage 1: Build (compile the application)
# --------------------------------------------------
echo "=== STAGE: Build ==="
cd product-service && mvn clean package -DskipTests -q
echo "Build artifact: $(ls target/*.jar)"
cd ..

# --------------------------------------------------
# Stage 2: Test (run unit tests)
# --------------------------------------------------
echo "=== STAGE: Test ==="
cd product-service && mvn test -q
cd ..

# --------------------------------------------------
# Stage 3: Docker Build & Tag
# --------------------------------------------------
echo "=== STAGE: Docker Build ==="
docker build -t localhost:5001/product-service:v2 product-service/

# --------------------------------------------------
# Stage 4: Docker Push (to local registry)
# --------------------------------------------------
echo "=== STAGE: Docker Push ==="
docker push localhost:5001/product-service:v2

# --------------------------------------------------
# Stage 5: Deploy (rolling update in K8s)
# --------------------------------------------------
echo "=== STAGE: Deploy ==="
kubectl set image deployment/product-service \
  product-service=localhost:5001/product-service:v2 \
  -n microservices

kubectl rollout status deployment/product-service -n microservices --timeout=120s

# --------------------------------------------------
# Stage 6: Integration Test (verify deployment)
# --------------------------------------------------
echo "=== STAGE: Integration Test ==="
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:30080/api/gateway/products)
if [ "$RESPONSE" = "200" ]; then
  echo "Integration test PASSED (HTTP $RESPONSE)"
else
  echo "Integration test FAILED (HTTP $RESPONSE)"
fi
```

> **Instructor Tip:** After the rolling update, run `kubectl get pods -n microservices -l app=product-service` and point out that the pod names have changed -- K8s created new pods with the v2 image and terminated the old ones.

### 4.4 Key Concepts

> **Concepts to reinforce with students:**
>
> - **Declarative pipelines** are preferred over scripted pipelines for readability and maintainability
> - **Parallel stages** reduce total pipeline time -- three 2-minute builds take 2 minutes instead of 6
> - **Rolling updates** (`kubectl set image` + `kubectl rollout status`) ensure zero-downtime deployments
> - **Build numbering** provides traceability -- every deployed image maps to a specific CI build
> - **Integration tests** in the pipeline catch deployment issues before they reach users

---

## 7. Lab 5: Monitoring with Prometheus & Grafana (15 min)

### 5.1 Setting Up the Monitoring Stack

```bash
cd /home/azureuser/final-demo
bash monitoring/setup-monitoring.sh
```

This script deploys:
- **Prometheus** -- time-series metrics database that scrapes `/actuator/prometheus` from all three services every 5 seconds
- **Grafana** -- visualization platform with a pre-configured "Microservices Monitor" dashboard

Verify the monitoring pods are running:

```bash
kubectl get pods -n monitoring
```

Expected output:

```
NAME                          READY   STATUS    RESTARTS   AGE
grafana-xxxxxxxxxx-xxxxx      1/1     Running   0          30s
prometheus-xxxxxxxxxx-xxxxx   1/1     Running   0          35s
```

### 5.2 Exploring Prometheus

Open http://localhost:30090 in your browser.

**Step 1: Check scrape targets**

Navigate to **Status > Targets**. You should see three jobs, all with State "UP":

| Job | Endpoint | State |
|-----|----------|-------|
| product-service | product-service.microservices:8081/actuator/prometheus | UP |
| order-service | order-service.microservices:8082/actuator/prometheus | UP |
| api-gateway | api-gateway.microservices:8080/actuator/prometheus | UP |

> **Instructor Tip:** If any target shows as "DOWN", check that the pods are running (`kubectl get pods -n microservices`) and that the actuator endpoint is exposed (`curl` from inside a pod).

**Step 2: Run PromQL queries**

In the Prometheus query bar (Graph tab), try these queries:

```promql
# Total HTTP request count (cumulative counter)
http_server_requests_seconds_count

# Request rate per second over the last 1 minute
rate(http_server_requests_seconds_count[1m])

# Average response time in milliseconds (per endpoint, per service)
rate(http_server_requests_seconds_sum[1m]) / rate(http_server_requests_seconds_count[1m]) * 1000

# JVM heap memory usage (bytes)
jvm_memory_used_bytes{area="heap"}

# Error rate (HTTP 5xx responses only)
rate(http_server_requests_seconds_count{status=~"5.."}[1m])

# Pod up/down status
up
```

> **Instructor Tip:** Walk through the difference between a **counter** (always increases: `http_server_requests_seconds_count`) and a **gauge** (goes up and down: `jvm_memory_used_bytes`). Counters need `rate()` to be useful; gauges can be queried directly.

### 5.3 Exploring Grafana

Open http://localhost:30030 in your browser. Log in with:

- **Username:** `admin`
- **Password:** `admin`

(Skip the password change prompt if shown.)

Navigate to **Dashboards** and open the **"Microservices Monitor"** dashboard.

The pre-configured dashboard has six panels:

| Panel | What It Shows | PromQL Behind It |
|-------|---------------|------------------|
| HTTP Request Rate (req/s) | Real-time request rate per endpoint per service | `rate(http_server_requests_seconds_count{application="..."}[1m])` |
| HTTP Average Response Time (ms) | Average latency per endpoint | `rate(sum[1m]) / rate(count[1m]) * 1000` |
| HTTP 5xx Error Rate | Server-side errors per second | `rate(count{status=~"5.."}[1m])` |
| JVM Memory Usage | Heap and non-heap memory per service | `sum(jvm_memory_used_bytes) by (area)` |
| Active Threads | Thread count per service | `jvm_threads_live_threads` |
| Pod Up/Down Status | Service availability indicator | `up{job="..."}` |

### 5.4 Generate Load for Visualization

> **Instructor Tip:** Open the Grafana dashboard on the projector while running this load generator. Students should see the graphs update in real-time -- this makes the abstract concept of metrics tangible.

```bash
# Generate traffic to populate the dashboard
echo "Generating load... watch the Grafana dashboard!"
for i in $(seq 1 100); do
  curl -s http://localhost:30080/api/gateway/products > /dev/null
  curl -s http://localhost:30080/api/gateway/orders > /dev/null
  curl -s -X POST http://localhost:30080/api/gateway/orders \
    -H "Content-Type: application/json" \
    -d '{"productId": 1, "quantity": 1}' > /dev/null
  sleep 0.5
done
echo "Load generation complete."
```

**What to observe in Grafana:**

- **Request Rate panel** -- lines should climb as traffic starts, then drop when the loop ends
- **Response Time panel** -- average latency should be low (single-digit milliseconds for product-service, slightly higher for order-service due to the inter-service call)
- **JVM Memory panel** -- slight increase as requests are processed, then garbage collection brings it down

### 5.5 Key Concepts

> **Concepts to reinforce with students:**
>
> - **Micrometer** (in pom.xml) is the metrics facade; **micrometer-registry-prometheus** exports metrics in Prometheus format via `/actuator/prometheus`
> - **Prometheus** actively scrapes (pulls) metrics from services -- services do not push metrics to Prometheus
> - **PromQL** is powerful but has a learning curve. Start with `rate()` for counters and direct queries for gauges.
> - **Observability** has three pillars: **Metrics** (Prometheus/Grafana -- what we set up), **Logs** (ELK/Loki -- not in this lab), and **Traces** (Jaeger/Zipkin -- not in this lab). In production, you need all three.
> - **Pre-built dashboards** save time. In production, teams use community dashboards as starting points and customize from there.

---

## 8. Lab 6: Chaos Engineering with Chaos Mesh (25 min)

> **Instructor Note:** This is the highlight of the lab. Chaos engineering transforms monitoring from a passive activity into an active tool for validating system resilience. Emphasize the scientific method: hypothesis, experiment, observation, conclusion.

### 6.1 What is Chaos Engineering?

Chaos engineering is the discipline of experimenting on a system to build confidence in its ability to withstand turbulent conditions in production.

**The process follows the scientific method:**

```
1. Define Steady State    -->  "What does 'normal' look like?"
2. Hypothesize            -->  "What SHOULD happen when X fails?"
3. Inject Failure         -->  "Apply the chaos experiment"
4. Observe                -->  "Watch metrics, logs, service responses"
5. Analyze & Learn        -->  "Did the system behave as expected?"
6. Fix Weaknesses         -->  "Improve resilience where gaps were found"
```

**Principles:**

- Start with a hypothesis about steady-state behavior
- Introduce real-world failures (network issues, pod crashes, resource exhaustion)
- Run experiments in a controlled environment first (that is what we are doing here)
- Minimize the blast radius -- test one thing at a time
- Automate experiments so they can be run regularly

### 6.2 Install Chaos Mesh

```bash
cd /home/azureuser/final-demo
bash chaos/install-chaos-mesh.sh
```

This script:
1. Adds the Chaos Mesh Helm repository
2. Creates the `chaos-mesh` namespace
3. Installs Chaos Mesh v2.7.0 with Kind-compatible settings (containerd runtime)
4. Waits for all Chaos Mesh pods to be ready

Verify the installation:

```bash
kubectl get pods -n chaos-mesh
```

Expected output (3-4 pods):

```
NAME                                        READY   STATUS    RESTARTS   AGE
chaos-controller-manager-xxxxxxxxxx-xxxxx   1/1     Running   0          30s
chaos-daemon-xxxxx                          1/1     Running   0          30s
chaos-dashboard-xxxxxxxxxx-xxxxx            1/1     Running   0          30s
```

### 6.3 Establish Steady State (Baseline)

Before injecting any failures, document what "normal" looks like:

```bash
bash chaos/steady-state-test.sh
```

Expected output:

```
=== Steady State Validation ===
PASS: Gateway Health (HTTP 200)
PASS: Products via Gateway (HTTP 200)
PASS: Orders via Gateway (HTTP 200)
PASS: Running pods count: 6 (expected >= 4)

Results: 4 passed, 0 failed
```

Also open the Grafana dashboard (http://localhost:30030) and note the baseline values for request rate, response time, and error rate. These are your steady-state reference points.

### 6.4 Start Continuous Monitoring (Terminal 2)

Open a **second terminal** and start the observation script:

```bash
cd /home/azureuser/final-demo
bash chaos/observe.sh
```

This will print pod status and service health every 5 seconds. Keep this running throughout all experiments.

> **Instructor Tip:** If you have a projector, show Terminal 2 (observe.sh) and the Grafana dashboard side by side. This gives students a real-time view of the impact of each experiment.

### 6.5 Experiment 1: Pod Kill (Resilience Test)

**The Experiment:**

```yaml
# chaos/experiments/pod-kill-product.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: pod-kill-product-service
  namespace: microservices
spec:
  action: pod-kill           # Kill the pod process
  mode: one                  # Kill ONE pod (not all)
  selector:
    namespaces:
      - microservices
    labelSelectors:
      app: product-service   # Target: product-service pods
  duration: "30s"
  scheduler:
    cron: "@every 2m"        # Repeat every 2 minutes
```

**Hypothesis:** "Kubernetes will detect the killed pod and restart it. Because we have 2 replicas, the surviving pod will handle all traffic. Service should recover fully within 30 seconds."

**Run the experiment:**

```bash
kubectl apply -f chaos/experiments/pod-kill-product.yaml
```

**Observe (in Terminal 2 and Grafana):**

```bash
# Watch pods in real-time -- you will see a pod go to Terminating, then a new one created
kubectl get pods -n microservices -l app=product-service -w
```

**What you should see:**

1. One product-service pod gets terminated
2. K8s immediately creates a replacement pod (status: ContainerCreating -> Running)
3. During the ~30 second restart window, the OTHER replica handles all requests
4. In Grafana, you may see a brief dip in request rate or a small spike in response time
5. No 5xx errors should appear because the surviving replica serves all traffic

**Clean up:**

```bash
kubectl delete -f chaos/experiments/pod-kill-product.yaml
```

> **Discussion point:** "Why did the service stay up even though a pod was killed?" Answer: because we configured `replicas: 2`. If we only had 1 replica, there would have been a brief outage. This demonstrates why high availability requires multiple replicas.

### 6.6 Experiment 2: Network Delay (Latency Test)

**The Experiment:**

```yaml
# chaos/experiments/network-delay.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: network-delay-product-service
  namespace: microservices
spec:
  action: delay
  mode: all                  # Affect ALL product-service pods
  selector:
    namespaces:
      - microservices
    labelSelectors:
      app: product-service
  delay:
    latency: "500ms"         # Add 500ms delay to every packet
    correlation: "50"        # 50% of packets are affected
    jitter: "100ms"          # +/- 100ms random variation
  duration: "60s"            # Lasts 60 seconds
```

**Hypothesis:** "Adding 500ms network delay to product-service will increase order creation response time (because order-service calls product-service), but all requests should still succeed. No errors expected."

**Run the experiment:**

```bash
kubectl apply -f chaos/experiments/network-delay.yaml

# Generate some orders to see the impact
for i in $(seq 1 10); do
  echo "Request $i:"
  curl -s -o /dev/null -w "HTTP %{http_code} - Time: %{time_total}s\n" \
    -X POST http://localhost:30080/api/gateway/orders \
    -H "Content-Type: application/json" \
    -d '{"productId": 1, "quantity": 1}'
  sleep 2
done
```

**What you should see:**

- Response times for order creation increase by approximately 500-600ms (due to the added latency on the product-service call)
- Direct product-service calls through the gateway also show increased latency
- In Grafana, the "HTTP Average Response Time" panel shows a clear spike during the experiment
- All requests should still return HTTP 200 -- latency is not failure

**Clean up:**

```bash
kubectl delete -f chaos/experiments/network-delay.yaml
```

> **Discussion point:** "In production, a 500ms delay can cascade. If order-service has a 2-second timeout for product-service calls, what happens when latency is 500ms + normal processing time?" This is where circuit breakers (Resilience4j, Hystrix) become important.

### 6.7 Experiment 3: Network Partition (Isolation Test)

**The Experiment:**

```yaml
# chaos/experiments/network-partition.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: network-partition-gateway-order
  namespace: microservices
spec:
  action: partition           # Complete network isolation
  mode: all
  selector:
    namespaces:
      - microservices
    labelSelectors:
      app: api-gateway        # Source: api-gateway
  direction: both             # Block in BOTH directions
  target:
    mode: all
    selector:
      namespaces:
        - microservices
      labelSelectors:
        app: order-service    # Target: order-service
  duration: "30s"
```

**Hypothesis:** "If the api-gateway cannot reach order-service, the `/api/gateway/orders` endpoint should return a 503 error, but `/api/gateway/products` should continue working normally. The gateway should degrade gracefully."

**Run the experiment:**

```bash
kubectl apply -f chaos/experiments/network-partition.yaml

# Test products endpoint (should WORK -- gateway can still reach product-service)
echo "Products (should work):"
curl -s http://localhost:30080/api/gateway/products | python3 -m json.tool

# Test orders endpoint (should FAIL -- gateway cannot reach order-service)
echo "Orders (should fail gracefully):"
curl -s http://localhost:30080/api/gateway/orders | python3 -m json.tool
```

**Expected output for orders:**

```json
{
    "error": "Order service is unavailable",
    "service": "order-service",
    "url": "http://order-service:8082/api/orders",
    "message": "I/O error on GET request...",
    "timestamp": "2026-03-03T..."
}
```

**What you should see:**

- Products endpoint returns HTTP 200 with product data (unaffected)
- Orders endpoint returns HTTP 503 with a structured error message (graceful degradation)
- The api-gateway does NOT crash -- it handles the failure and returns useful error information

**Clean up:**

```bash
kubectl delete -f chaos/experiments/network-partition.yaml
```

> **Discussion point:** "This experiment demonstrates **partial failure** -- part of the system is broken but the rest continues working. In microservices, you must design each endpoint to fail independently. A failure in order-service should never take down the entire gateway."

### 6.8 Experiment 4: CPU Stress (Resource Pressure Test)

**The Experiment:**

```yaml
# chaos/experiments/cpu-stress.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: StressChaos
metadata:
  name: cpu-stress-order-service
  namespace: microservices
spec:
  mode: all
  selector:
    namespaces:
      - microservices
    labelSelectors:
      app: order-service
  stressors:
    cpu:
      workers: 2             # 2 CPU-burning threads
      load: 80               # Target 80% CPU usage
  duration: "60s"
```

**Hypothesis:** "CPU stress on order-service will increase response times and may trigger resource throttling (due to the 500m CPU limit), but requests should still be served. K8s resource limits should prevent the stress from affecting other pods."

**Run the experiment:**

```bash
kubectl apply -f chaos/experiments/cpu-stress.yaml

# Watch CPU usage
kubectl top pods -n microservices -l app=order-service

# Test response times
for i in $(seq 1 5); do
  curl -s -o /dev/null -w "Order request $i: HTTP %{http_code} - Time: %{time_total}s\n" \
    http://localhost:30080/api/gateway/orders
  sleep 2
done
```

**What you should see in Grafana:**

- JVM Memory panel may show increased GC activity
- Response times increase as the CPU-constrained JVM struggles
- Thread count may increase as requests queue up
- The resource `limits.cpu: 500m` in the deployment YAML prevents the stress from consuming the entire node

**Clean up:**

```bash
kubectl delete -f chaos/experiments/cpu-stress.yaml
```

> **Discussion point:** "This is why we set resource limits. Without `limits.cpu: 500m`, a runaway process in one pod could starve all other pods on the same node. Resource limits are a critical safety net in multi-tenant Kubernetes clusters."

### 6.9 Experiment 5: Pod Failure (Availability Test)

**The Experiment:**

```yaml
# chaos/experiments/pod-failure.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: pod-failure-api-gateway
  namespace: microservices
spec:
  action: pod-failure        # Makes the pod enter a failed state
  mode: one                  # Only one of the two replicas
  selector:
    namespaces:
      - microservices
    labelSelectors:
      app: api-gateway
  duration: "30s"
```

**Hypothesis:** "With 2 api-gateway replicas, killing one should not affect service availability. The K8s Service load balancer should route all traffic to the healthy replica."

**Run the experiment:**

```bash
kubectl apply -f chaos/experiments/pod-failure.yaml

# Immediately test -- should still work because the other replica is healthy
for i in $(seq 1 10); do
  curl -s -o /dev/null -w "Gateway request $i: HTTP %{http_code}\n" \
    http://localhost:30080/api/gateway/health
  sleep 1
done
```

**What you should see:**

- One gateway pod enters a failed state
- All requests still succeed (HTTP 200) because the surviving replica handles traffic
- After 30 seconds, the failed pod recovers
- In Grafana, the Pod Up/Down Status panel may briefly show one instance as DOWN

**Clean up:**

```bash
kubectl delete -f chaos/experiments/pod-failure.yaml
```

### 6.10 Run All Experiments Sequentially

> **Instructor Note:** If time permits, run the full suite. This takes approximately 5-6 minutes and demonstrates all experiments back-to-back with automated cleanup between each.

```bash
bash chaos/run-all-experiments.sh
```

This script runs six experiments in sequence:
1. Pod Kill - Product Service (40s observation)
2. Network Delay - Product Service (70s observation)
3. CPU Stress - Order Service (70s observation)
4. Network Partition - Gateway to Order (40s observation)
5. Pod Failure - API Gateway (40s observation)
6. Pod Kill - Order Service (40s observation)

Each experiment is followed by a 15-second recovery period.

### 6.11 Bonus: Access the Chaos Mesh Dashboard

```bash
kubectl port-forward -n chaos-mesh svc/chaos-dashboard 2333:2333
```

Open http://localhost:2333 to see a visual dashboard showing all experiments, their status, and timeline.

### 6.12 Key Concepts

> **Concepts to reinforce with students:**
>
> - **Always define steady state first** -- you cannot detect degradation if you do not know what "normal" looks like
> - **Hypothesis-driven experiments** -- chaos engineering is NOT random destruction. Every experiment should have a clear hypothesis about expected behavior.
> - **Replicas are essential** -- almost every experiment showed that having 2+ replicas prevented outages
> - **Graceful degradation matters** -- the api-gateway returned structured 503 errors instead of crashing; order-service continued processing orders even when product-service was down
> - **Monitor during experiments** -- Grafana and the observe.sh script are critical for understanding impact. Without monitoring, chaos experiments are just destruction.
> - **Fix what you find** -- if an experiment reveals a weakness (e.g., no timeout on inter-service calls), fix it and re-run the experiment to validate the fix

---

## 9. Lab 7: Putting It All Together (10 min)

### End-to-End Scenario: Deploy a Change and Validate with Chaos

This final exercise ties together everything learned in Labs 1-6: code change, CI/CD, monitoring, and chaos validation.

**Scenario:** You need to add a new product to the catalog, deploy the change, verify it works, and validate that the system remains resilient.

**Step 1: Make a code change**

> **Instructor Note:** For the demo, we will simulate a code change by rebuilding with a new tag. In a real workflow, students would modify `ProductController.java` to add a fourth product.

```bash
cd /home/azureuser/final-demo
```

**Step 2: Build the new image (CI)**

```bash
docker build -t localhost:5001/product-service:v3 product-service/
docker push localhost:5001/product-service:v3
echo "CI complete: image pushed to registry as v3"
```

**Step 3: Deploy to Kubernetes (CD)**

```bash
kubectl set image deployment/product-service \
  product-service=localhost:5001/product-service:v3 \
  -n microservices

kubectl rollout status deployment/product-service -n microservices --timeout=120s
echo "CD complete: product-service v3 deployed"
```

**Step 4: Verify with monitoring**

```bash
# Functional verification
curl -s http://localhost:30080/api/gateway/products | python3 -m json.tool
curl -s http://localhost:30080/api/gateway/health | python3 -m json.tool

# Steady-state verification
bash chaos/steady-state-test.sh
```

Check Grafana to confirm metrics are flowing normally from the new pods.

**Step 5: Validate resilience with chaos**

```bash
# Kill a product-service pod to confirm the new deployment is resilient
kubectl apply -f chaos/experiments/pod-kill-product.yaml

# Watch recovery
kubectl get pods -n microservices -l app=product-service -w

# Verify service still responds
sleep 10
curl -s http://localhost:30080/api/gateway/products | python3 -m json.tool

# Clean up
kubectl delete -f chaos/experiments/pod-kill-product.yaml
```

**Step 6: Confirm steady state**

```bash
bash chaos/steady-state-test.sh
```

All four checks should pass, confirming the deployment is healthy and resilient.

> **Instructor Tip:** This is the workflow that mature engineering teams follow: every deployment is validated not just with functional tests but also with chaos experiments. The goal is confidence that the new version handles failures as well as (or better than) the previous version.

---

## 10. Troubleshooting Guide

### Pods Stuck in ImagePullBackOff

**Symptom:**

```
NAME                              READY   STATUS             RESTARTS   AGE
product-service-xxxxxxxxxx-xxx    0/1     ImagePullBackOff   0          2m
```

**Cause:** The Kind cluster cannot reach the local Docker registry.

**Fix:**

```bash
# Verify registry is running
docker ps | grep kind-registry

# If not running, start it
docker run -d --restart=always -p 5001:5000 --network bridge --name kind-registry registry:2

# Connect registry to Kind network
docker network connect kind kind-registry

# Verify image is in the registry
curl -s http://localhost:5001/v2/_catalog

# Rebuild and push the image
docker build -t localhost:5001/product-service:latest product-service/
docker push localhost:5001/product-service:latest

# Restart the pod
kubectl delete pod -l app=product-service -n microservices
```

### Pods in CrashLoopBackOff

**Symptom:**

```
NAME                              READY   STATUS             RESTARTS   AGE
order-service-xxxxxxxxxx-xxx      0/1     CrashLoopBackOff   5          3m
```

**Cause:** The application is crashing on startup (usually a configuration or dependency issue).

**Fix:**

```bash
# Check the logs to see the actual error
kubectl logs -n microservices deployment/order-service --previous

# Common causes:
# 1. Port conflict -- another process using the same port
# 2. Missing environment variable -- check the deployment env section
# 3. Java out-of-memory -- increase memory limits

# Check events for more details
kubectl describe pod -l app=order-service -n microservices
```

### Services Unreachable (Connection Refused)

**Symptom:** `curl http://localhost:30080/api/gateway/health` returns connection refused.

**Fix:**

```bash
# Verify the service exists and has endpoints
kubectl get svc -n microservices
kubectl get endpoints -n microservices

# If endpoints show <none>, the pods are not ready
kubectl get pods -n microservices

# Verify NodePort mapping
kubectl get svc api-gateway -n microservices -o wide

# For Kind specifically, verify port mappings in kind-config.yaml
docker port microservices-demo-control-plane
```

### Prometheus Targets Showing as DOWN

**Symptom:** In Prometheus UI (Status > Targets), targets show State "DOWN".

**Fix:**

```bash
# Verify the actuator endpoint is accessible from inside the cluster
kubectl exec -n monitoring deployment/prometheus -- \
  wget -qO- http://product-service.microservices:8081/actuator/prometheus | head -5

# If that fails, verify the service and endpoints
kubectl get endpoints product-service -n microservices

# Check that management endpoints are exposed in application.yml
# Should include: health,info,prometheus,metrics

# Verify Prometheus config
kubectl get configmap prometheus-config -n monitoring -o yaml
```

### Chaos Mesh Experiments Not Working

**Symptom:** Experiments are applied but have no visible effect.

**Fix:**

```bash
# Check Chaos Mesh pods are running
kubectl get pods -n chaos-mesh

# Check experiment status
kubectl get podchaos -n microservices
kubectl get networkchaos -n microservices
kubectl get stresschaos -n microservices

# Describe the experiment for events/errors
kubectl describe podchaos pod-kill-product-service -n microservices

# Check Chaos Mesh controller logs
kubectl logs -n chaos-mesh deployment/chaos-controller-manager | tail -20

# Common issue: RBAC permissions
# The chaos-mesh ServiceAccount needs permissions to the microservices namespace
```

### Kind Cluster Issues

**Symptom:** Cluster is unresponsive or in a bad state.

**Fix (nuclear option):**

```bash
# Tear down everything and start fresh
bash teardown.sh

# Recreate
bash setup.sh
```

### Useful Debugging Commands

```bash
# Get detailed pod information
kubectl describe pod <pod-name> -n microservices

# Stream logs from a specific pod
kubectl logs -f <pod-name> -n microservices

# Execute a command inside a running pod
kubectl exec -it <pod-name> -n microservices -- /bin/sh

# Check resource usage across the cluster
kubectl top nodes
kubectl top pods -n microservices

# Check events in a namespace (sorted by time)
kubectl get events -n microservices --sort-by='.lastTimestamp'

# Port-forward to a specific pod for direct testing
kubectl port-forward -n microservices svc/product-service 8081:8081

# Check cluster-level info
kubectl cluster-info
kubectl get nodes -o wide
```

---

## 11. Key Takeaways & Best Practices

### 1. Microservices Architecture

- **Keep services small and focused** -- each service owns one business domain (products, orders)
- **Handle failures gracefully** -- never let a downstream failure crash your service. Use try/catch, timeouts, and fallback responses.
- **Design for partial failure** -- the system should continue working (possibly in degraded mode) when some services are down
- **Use DTOs for inter-service communication** -- do not expose internal models across service boundaries (notice `ProductDTO` in order-service is separate from `Product` in product-service)

### 2. Docker

- **Use multi-stage builds** -- reduce image size by 70-80%; ship only what is needed at runtime
- **Cache dependencies** -- copy `pom.xml` before source code so `mvn dependency:go-offline` is cached
- **Use specific base image tags** -- `eclipse-temurin:17-jre-alpine` not `java:latest`
- **Minimize image layers** -- combine related commands where possible

### 3. Kubernetes

- **Always use readiness AND liveness probes** -- readiness controls traffic routing; liveness controls restart behavior
- **Set resource requests AND limits** -- requests guarantee minimum resources; limits prevent runaway usage
- **Run multiple replicas** -- for any service that matters, `replicas: 2` is the minimum for high availability
- **Use namespaces for isolation** -- separate microservices, jenkins, monitoring, and chaos-mesh
- **Externalize configuration** -- use environment variables and ConfigMaps, not hardcoded values

### 4. CI/CD

- **Automate everything** -- manual steps are error-prone and slow. Every stage from build to deploy should be scripted.
- **Test before deploy** -- run unit tests, integration tests, and smoke tests before promoting to production
- **Use immutable image tags** -- tag images with build numbers (`v1`, `v2`, `BUILD_NUMBER`), not just `latest`
- **Rolling updates by default** -- K8s supports zero-downtime deployments out of the box
- **Parallel where possible** -- build and test stages for independent services should run concurrently

### 5. Monitoring & Observability

- **Instrument from day one** -- adding monitoring after an outage is too late. Micrometer + Prometheus is nearly zero-effort with Spring Boot.
- **Define SLIs (Service Level Indicators)** -- request rate, error rate, and latency are the "golden signals"
- **Set up dashboards before you need them** -- when an incident occurs, you should already have the dashboards ready
- **Observability = Metrics + Logs + Traces** -- metrics (Prometheus) tell you WHAT is wrong; logs tell you WHY; traces tell you WHERE in a distributed call chain

### 6. Chaos Engineering

- **Test in production-like environments** -- chaos experiments in a toy environment give false confidence. Kind is a good start, but eventually test in staging and production.
- **Start small** -- begin with single pod kills, then progress to network delays, partitions, and multi-failure scenarios
- **Always have a hypothesis** -- "I think X will happen when Y fails." If you are wrong, you have found a gap in your understanding.
- **Automate experiments** -- run chaos experiments as part of your CI/CD pipeline or on a regular schedule
- **Fix what you find** -- chaos engineering without remediation is just expensive destruction

---

## Quick Reference Commands

| Action | Command |
|--------|---------|
| Full setup | `bash setup.sh` |
| Full teardown | `bash teardown.sh` |
| Build all images | `bash build-images.sh` |
| Deploy all services | `bash deploy.sh` |
| Health check all services | `bash test-services.sh` |
| Setup monitoring | `bash monitoring/setup-monitoring.sh` |
| Install Chaos Mesh | `bash chaos/install-chaos-mesh.sh` |
| Run steady-state check | `bash chaos/steady-state-test.sh` |
| Start continuous monitoring | `bash chaos/observe.sh` |
| Run all chaos experiments | `bash chaos/run-all-experiments.sh` |
| Get all pods (microservices) | `kubectl get pods -n microservices` |
| Get all pods (all namespaces) | `kubectl get pods -A` |
| Stream pod logs | `kubectl logs -f deployment/<name> -n microservices` |
| Scale a deployment | `kubectl scale deployment/<name> --replicas=<n> -n microservices` |
| Rolling update | `kubectl set image deployment/<name> <name>=localhost:5001/<name>:<tag> -n microservices` |
| Check rollout status | `kubectl rollout status deployment/<name> -n microservices` |
| Rollback a deployment | `kubectl rollout undo deployment/<name> -n microservices` |
| Get Jenkins password | `kubectl exec -n jenkins $(kubectl get pod -n jenkins -l app=jenkins -o jsonpath='{.items[0].metadata.name}') -- cat /var/jenkins_home/secrets/initialAdminPassword` |
| Port-forward Chaos Dashboard | `kubectl port-forward -n chaos-mesh svc/chaos-dashboard 2333:2333` |
| Delete a chaos experiment | `kubectl delete -f chaos/experiments/<file>.yaml` |
| Check cluster events | `kubectl get events -n microservices --sort-by='.lastTimestamp'` |

---

## Access Points Summary

| Service | URL | Credentials |
|---------|-----|-------------|
| API Gateway (microservices entry point) | http://localhost:30080 | N/A |
| API Gateway Health | http://localhost:30080/api/gateway/health | N/A |
| Products via Gateway | http://localhost:30080/api/gateway/products | N/A |
| Orders via Gateway | http://localhost:30080/api/gateway/orders | N/A |
| Jenkins | http://localhost:30000 | admin / (see password command above) |
| Prometheus | http://localhost:30090 | N/A |
| Grafana | http://localhost:30030 | admin / admin |
| Chaos Mesh Dashboard | http://localhost:2333 (requires port-forward) | N/A |

---

## Namespaces Summary

| Namespace | Contents |
|-----------|----------|
| `microservices` | product-service, order-service, api-gateway (deployments + services) |
| `jenkins` | Jenkins server (deployment + service + RBAC) |
| `monitoring` | Prometheus, Grafana (deployments + services + configs) |
| `chaos-mesh` | Chaos Mesh controller, daemon, dashboard |

---

> **Final Instructor Note:** This lab demonstrates the full lifecycle of building, deploying, monitoring, and validating microservices. The key message for students is that each of these practices (containerization, orchestration, CI/CD, monitoring, chaos engineering) is valuable individually, but they are transformative when combined. Modern software engineering is not just about writing code -- it is about building systems that you can deploy confidently, observe in real-time, and trust under failure. The tools will evolve, but these principles endure.
