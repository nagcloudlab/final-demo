package com.demo.gateway.service;

import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import io.github.resilience4j.retry.annotation.Retry;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

@Service
public class OrderServiceProxy {

    private final RestTemplate restTemplate;

    @Value("${order.service.url:http://localhost:8082}")
    private String orderServiceUrl;

    public OrderServiceProxy(RestTemplate restTemplate) {
        this.restTemplate = restTemplate;
    }

    @CircuitBreaker(name = "orderService", fallbackMethod = "getOrdersFallback")
    @Retry(name = "orderService")
    public String getOrders() {
        return restTemplate.getForObject(orderServiceUrl + "/api/orders", String.class);
    }

    public String getOrdersFallback(Exception e) {
        return "[{\"id\":0,\"productId\":0,\"quantity\":0,\"totalPrice\":0,\"status\":\"SERVICE UNAVAILABLE - Circuit breaker OPEN: " + e.getMessage() + "\"}]";
    }
}
