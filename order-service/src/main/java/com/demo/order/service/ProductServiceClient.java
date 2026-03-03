package com.demo.order.service;

import com.demo.order.dto.ProductDTO;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

@Service
public class ProductServiceClient {

    private final RestTemplate restTemplate;

    @Value("${product.service.url:http://localhost:8081}")
    private String productServiceUrl;

    public ProductServiceClient(RestTemplate restTemplate) {
        this.restTemplate = restTemplate;
    }

    public ProductDTO getProduct(Long productId) {
        try {
            String url = productServiceUrl + "/api/products/" + productId;
            return restTemplate.getForObject(url, ProductDTO.class);
        } catch (Exception e) {
            System.out.println("Failed to reach product-service: " + e.getMessage());
            return null;
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
