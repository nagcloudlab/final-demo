package com.demo.gateway.controller;

import com.demo.gateway.service.OrderServiceProxy;
import com.demo.gateway.service.ProductServiceProxy;
import io.github.resilience4j.circuitbreaker.CircuitBreaker;
import io.github.resilience4j.circuitbreaker.CircuitBreakerRegistry;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.RestTemplate;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/gateway")
public class GatewayController {

    private final RestTemplate restTemplate;
    private final ProductServiceProxy productServiceProxy;
    private final OrderServiceProxy orderServiceProxy;
    private final CircuitBreakerRegistry circuitBreakerRegistry;

    @Value("${product.service.url}")
    private String productServiceUrl;

    @Value("${order.service.url}")
    private String orderServiceUrl;

    public GatewayController(RestTemplate restTemplate,
                             ProductServiceProxy productServiceProxy,
                             OrderServiceProxy orderServiceProxy,
                             CircuitBreakerRegistry circuitBreakerRegistry) {
        this.restTemplate = restTemplate;
        this.productServiceProxy = productServiceProxy;
        this.orderServiceProxy = orderServiceProxy;
        this.circuitBreakerRegistry = circuitBreakerRegistry;
    }

    @GetMapping("/products")
    public ResponseEntity<Object> getProducts() {
        try {
            String result = productServiceProxy.getProducts();
            return ResponseEntity.ok(result);
        } catch (Exception e) {
            Map<String, Object> fallback = new HashMap<>();
            fallback.put("error", "Product service is unavailable");
            fallback.put("service", "product-service");
            fallback.put("url", productServiceUrl + "/api/products");
            fallback.put("message", e.getMessage());
            fallback.put("timestamp", LocalDateTime.now().toString());
            return ResponseEntity.status(503).body(fallback);
        }
    }

    @GetMapping("/orders")
    public ResponseEntity<Object> getOrders() {
        try {
            String result = orderServiceProxy.getOrders();
            return ResponseEntity.ok(result);
        } catch (Exception e) {
            Map<String, Object> fallback = new HashMap<>();
            fallback.put("error", "Order service is unavailable");
            fallback.put("service", "order-service");
            fallback.put("url", orderServiceUrl + "/api/orders");
            fallback.put("message", e.getMessage());
            fallback.put("timestamp", LocalDateTime.now().toString());
            return ResponseEntity.status(503).body(fallback);
        }
    }

    @GetMapping("/circuit-status")
    public ResponseEntity<Map<String, Object>> getCircuitBreakerStatus() {
        Map<String, Object> status = new HashMap<>();
        status.put("timestamp", LocalDateTime.now().toString());

        CircuitBreaker productCB = circuitBreakerRegistry.circuitBreaker("productService");
        Map<String, Object> productStatus = new HashMap<>();
        productStatus.put("state", productCB.getState().name());
        productStatus.put("failureRate", productCB.getMetrics().getFailureRate());
        productStatus.put("numberOfFailedCalls", productCB.getMetrics().getNumberOfFailedCalls());
        productStatus.put("numberOfSuccessfulCalls", productCB.getMetrics().getNumberOfSuccessfulCalls());
        productStatus.put("numberOfNotPermittedCalls", productCB.getMetrics().getNumberOfNotPermittedCalls());
        status.put("productService", productStatus);

        CircuitBreaker orderCB = circuitBreakerRegistry.circuitBreaker("orderService");
        Map<String, Object> orderStatus = new HashMap<>();
        orderStatus.put("state", orderCB.getState().name());
        orderStatus.put("failureRate", orderCB.getMetrics().getFailureRate());
        orderStatus.put("numberOfFailedCalls", orderCB.getMetrics().getNumberOfFailedCalls());
        orderStatus.put("numberOfSuccessfulCalls", orderCB.getMetrics().getNumberOfSuccessfulCalls());
        orderStatus.put("numberOfNotPermittedCalls", orderCB.getMetrics().getNumberOfNotPermittedCalls());
        status.put("orderService", orderStatus);

        return ResponseEntity.ok(status);
    }

    @GetMapping("/health")
    public ResponseEntity<Map<String, Object>> gatewayHealth() {
        Map<String, Object> health = new HashMap<>();
        health.put("service", "api-gateway");
        health.put("status", "UP");
        health.put("timestamp", LocalDateTime.now().toString());

        // Check product service health
        Map<String, Object> productHealth = new HashMap<>();
        try {
            String productHealthUrl = productServiceUrl + "/actuator/health";
            ResponseEntity<Object> productResponse = restTemplate.getForEntity(productHealthUrl, Object.class);
            productHealth.put("status", "UP");
            productHealth.put("url", productServiceUrl);
            productHealth.put("details", productResponse.getBody());
        } catch (Exception e) {
            productHealth.put("status", "DOWN");
            productHealth.put("url", productServiceUrl);
            productHealth.put("error", e.getMessage());
        }
        health.put("product-service", productHealth);

        // Check order service health
        Map<String, Object> orderHealth = new HashMap<>();
        try {
            String orderHealthUrl = orderServiceUrl + "/actuator/health";
            ResponseEntity<Object> orderResponse = restTemplate.getForEntity(orderHealthUrl, Object.class);
            orderHealth.put("status", "UP");
            orderHealth.put("url", orderServiceUrl);
            orderHealth.put("details", orderResponse.getBody());
        } catch (Exception e) {
            orderHealth.put("status", "DOWN");
            orderHealth.put("url", orderServiceUrl);
            orderHealth.put("error", e.getMessage());
        }
        health.put("order-service", orderHealth);

        return ResponseEntity.ok(health);
    }
}
