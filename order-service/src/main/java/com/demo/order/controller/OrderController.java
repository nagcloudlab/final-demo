package com.demo.order.controller;

import com.demo.order.dto.ProductDTO;
import com.demo.order.model.Order;
import com.demo.order.service.ProductServiceClient;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicLong;

@RestController
@RequestMapping("/api/orders")
public class OrderController {

    private final List<Order> orders = new ArrayList<>();
    private final AtomicLong idCounter = new AtomicLong(3);
    private final ProductServiceClient productServiceClient;

    public OrderController(ProductServiceClient productServiceClient) {
        this.productServiceClient = productServiceClient;

        // Sample orders with productIds matching product-service data:
        // Product 1 = Laptop ($999.99), Product 2 = Wireless Mouse ($29.99)
        orders.add(new Order(1L, 1L, "Laptop", 2, 1999.98, "CONFIRMED"));
        orders.add(new Order(2L, 2L, "Wireless Mouse", 1, 29.99, "PENDING"));
    }

    @GetMapping
    public ResponseEntity<List<Order>> getAllOrders() {
        return ResponseEntity.ok(orders);
    }

    @GetMapping("/{id}")
    public ResponseEntity<Order> getOrderById(@PathVariable Long id) {
        Optional<Order> order = orders.stream()
                .filter(o -> o.getId().equals(id))
                .findFirst();
        return order.map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

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
                // Product-service unreachable or product not found
                if (order.getProductName() == null) {
                    order.setProductName("Unknown (product-service unavailable)");
                }
                // Keep the provided totalPrice as-is
            }
        }

        orders.add(order);
        return ResponseEntity.status(HttpStatus.CREATED).body(order);
    }

    @GetMapping("/with-products")
    public ResponseEntity<List<Map<String, Object>>> getOrdersWithProducts() {
        List<Map<String, Object>> enrichedOrders = new ArrayList<>();

        for (Order order : orders) {
            Map<String, Object> enriched = new HashMap<>();
            enriched.put("id", order.getId());
            enriched.put("productId", order.getProductId());
            enriched.put("productName", order.getProductName());
            enriched.put("quantity", order.getQuantity());
            enriched.put("totalPrice", order.getTotalPrice());
            enriched.put("status", order.getStatus());

            // Enrich with live product details from product-service
            if (order.getProductId() != null) {
                ProductDTO product = productServiceClient.getProduct(order.getProductId());
                if (product != null) {
                    Map<String, Object> productDetails = new HashMap<>();
                    productDetails.put("id", product.getId());
                    productDetails.put("name", product.getName());
                    productDetails.put("price", product.getPrice());
                    productDetails.put("description", product.getDescription());
                    enriched.put("productDetails", productDetails);
                    enriched.put("productServiceStatus", "CONNECTED");
                } else {
                    enriched.put("productDetails", null);
                    enriched.put("productServiceStatus", "UNAVAILABLE");
                }
            }

            enrichedOrders.add(enriched);
        }

        return ResponseEntity.ok(enrichedOrders);
    }

    @GetMapping("/service-health")
    public ResponseEntity<Map<String, Object>> serviceHealth() {
        Map<String, Object> health = new HashMap<>();
        health.put("orderService", "UP");

        boolean productServiceHealthy = productServiceClient.isProductServiceHealthy();
        health.put("productService", productServiceHealthy ? "UP" : "DOWN");
        health.put("interServiceCommunication", productServiceHealthy ? "HEALTHY" : "DEGRADED");

        return ResponseEntity.ok(health);
    }

    @GetMapping("/health")
    public ResponseEntity<String> health() {
        return ResponseEntity.ok("Order Service is UP!");
    }
}
