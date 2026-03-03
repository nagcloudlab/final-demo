package com.demo.product.controller;

import com.demo.product.model.Product;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicLong;

@RestController
@RequestMapping("/api/products")
public class ProductController {

    private final List<Product> products = new ArrayList<>();
    private final AtomicLong idCounter = new AtomicLong(3);

    public ProductController() {
        products.add(new Product(1L, "Laptop", 999.99, "High-performance laptop with 16GB RAM"));
        products.add(new Product(2L, "Wireless Mouse", 29.99, "Ergonomic wireless mouse with USB receiver"));
        products.add(new Product(3L, "Mechanical Keyboard", 79.99, "RGB mechanical keyboard with Cherry MX switches"));
    }

    @GetMapping
    public ResponseEntity<List<Product>> getAllProducts() {
        return ResponseEntity.ok(products);
    }

    @GetMapping("/{id}")
    public ResponseEntity<Product> getProductById(@PathVariable Long id) {
        Optional<Product> product = products.stream()
                .filter(p -> p.getId().equals(id))
                .findFirst();

        return product.map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping
    public ResponseEntity<Product> addProduct(@RequestBody Product product) {
        product.setId(idCounter.incrementAndGet());
        products.add(product);
        return ResponseEntity.status(HttpStatus.CREATED).body(product);
    }

    @GetMapping("/health")
    public ResponseEntity<String> healthCheck() {
        return ResponseEntity.ok("Product Service is UP!");
    }
}
