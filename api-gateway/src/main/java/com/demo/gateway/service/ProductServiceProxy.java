package com.demo.gateway.service;

import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import io.github.resilience4j.retry.annotation.Retry;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

@Service
public class ProductServiceProxy {

    private final RestTemplate restTemplate;

    @Value("${product.service.url:http://localhost:8081}")
    private String productServiceUrl;

    public ProductServiceProxy(RestTemplate restTemplate) {
        this.restTemplate = restTemplate;
    }

    @CircuitBreaker(name = "productService", fallbackMethod = "getProductsFallback")
    @Retry(name = "productService")
    public String getProducts() {
        return restTemplate.getForObject(productServiceUrl + "/api/products", String.class);
    }

    public String getProductsFallback(Exception e) {
        return "[{\"id\":0,\"name\":\"Service Temporarily Unavailable\",\"price\":0,\"description\":\"Product service is currently down. Circuit breaker is OPEN. Last error: " + e.getMessage() + "\"}]";
    }
}
