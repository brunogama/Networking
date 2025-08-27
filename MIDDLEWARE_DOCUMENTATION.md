# Networking Middleware Architecture

This document describes the advanced middleware architecture implemented for the Networking framework, providing comprehensive error handling, performance monitoring, caching, and authentication capabilities.

## Overview

The Networking framework now includes five sophisticated middleware components:

1. **CircuitBreakerMiddleware** - Implements circuit breaker pattern with failure detection and recovery
2. **AuthenticationMiddleware** - Handles token-based authentication with automatic refresh
3. **CachingMiddleware** - Provides response caching with TTL and invalidation strategies
4. **RequestTimingMiddleware** - Collects performance metrics and timing information
5. **RetryMiddleware** (Enhanced) - Improved with exponential backoff and jitter strategies

## Middleware Components

### 1. CircuitBreakerMiddleware

Prevents cascading failures by temporarily blocking requests to failing services.

**Key Features:**
- Three states: Closed (normal), Open (blocked), Half-Open (testing recovery)
- Configurable failure thresholds and recovery timeouts
- Rolling window failure counting
- Thread-safe actor implementation

**Usage:**
```swift
let circuitBreaker = CircuitBreakerMiddleware.default(client: httpClient)

// Or with custom configuration
let circuitBreaker = CircuitBreakerMiddleware(
    configuration: CircuitBreakerMiddleware.Configuration(
        failureThreshold: 5,
        recoveryTimeout: 60.0,
        successThreshold: 3
    ),
    client: httpClient
)
```

**Configuration Options:**
- `failureThreshold`: Consecutive failures needed to open circuit (default: 5)
- `recoveryTimeout`: Time to wait before half-open transition (default: 60s)
- `successThreshold`: Successes needed in half-open to close circuit (default: 3)
- `rollingWindow`: Time window for failure counting (default: 120s)

### 2. AuthenticationMiddleware

Handles token-based authentication with automatic refresh and retry logic.

**Key Features:**
- Automatic token injection into requests
- Token refresh on 401 errors
- Concurrent refresh protection (prevents multiple simultaneous refreshes)
- Flexible token provider interface

**Usage:**
```swift
// With memory-based token provider
let authMiddleware = AuthenticationMiddleware.withMemoryProvider(
    client: httpClient,
    initialToken: "your-token",
    refreshHandler: {
        // Your token refresh logic
        return try await refreshTokenFromAPI()
    }
)

// With custom token provider
let customProvider = ClosureTokenProvider(
    getCurrentToken: { return await getStoredToken() },
    refreshToken: { return try await performTokenRefresh() }
)

let authMiddleware = AuthenticationMiddleware(
    configuration: AuthenticationMiddleware.Configuration(),
    tokenProvider: customProvider,
    client: httpClient
)
```

**Token Provider Interface:**
```swift
protocol TokenProvider: Sendable {
    func getCurrentToken() async throws -> String?
    func refreshToken() async throws -> String
    func shouldRefreshToken(for error: HTTPError) async -> Bool
}
```

### 3. CachingMiddleware

Provides HTTP response caching with TTL, conditional requests, and flexible storage.

**Key Features:**
- Configurable TTL with Cache-Control header support
- Conditional requests (If-None-Match, If-Modified-Since)
- Pluggable storage backends
- Memory cache implementation included
- Cache invalidation and cleanup

**Usage:**
```swift
// Simple memory-based caching
let cachingMiddleware = CachingMiddleware.withMemoryStorage(
    client: httpClient,
    ttl: 300.0, // 5 minutes
    maxCacheSize: 100
)

// Custom configuration
let cachingMiddleware = CachingMiddleware.withCustomConfiguration(
    client: httpClient
) { config in
    config.defaultTTL = 600.0 // 10 minutes
    config.useConditionalRequests = true
    config.shouldCache = { request, response in
        // Custom caching logic
        return request.method == .GET && response.status.isSuccess
    }
}
```

**Cache Storage Interface:**
```swift
protocol CacheStorage: Sendable {
    func get(_ key: String) async -> CacheEntry?
    func set(_ key: String, entry: CacheEntry) async
    func remove(_ key: String) async
    func removeAll() async
    func removeExpired() async
}
```

### 4. RequestTimingMiddleware

Collects comprehensive performance metrics and timing information.

**Key Features:**
- Request/response timing measurement
- Body size tracking
- Success/failure categorization
- Multiple collector backends (memory, logging, composite)
- Statistical analysis (average, p95 response times)

**Usage:**
```swift
// With memory collector for analysis
let (timingMiddleware, collector) = RequestTimingMiddleware.withMemoryCollector(
    maxMetricsCount: 1000
)

// Access metrics
let averageTime = await collector.averageResponseTime
let p95Time = await collector.p95ResponseTime
let failedRequests = await collector.failedRequests

// With logging collector
let timingMiddleware = RequestTimingMiddleware.withLogging(
    logLevel: .info
)

// With both memory and logging
let (timingMiddleware, collector) = RequestTimingMiddleware.withMemoryAndLogging(
    maxMetricsCount: 1000,
    logLevel: .info
)
```

**Metrics Collector Interface:**
```swift
protocol MetricsCollector: Sendable {
    func recordMetrics(_ metrics: RequestMetrics) async
}
```

### 5. Enhanced RetryMiddleware

Improved retry middleware with exponential backoff and jitter strategies.

**Key Features:**
- Multiple jitter strategies (none, full, equal, decorrelated)
- Enhanced retry conditions with attempt-aware logic
- Response-based retry triggers
- Custom delay calculation support
- Thread-safe jitter state management

**Usage:**
```swift
// Default configuration with equal jitter
let retryMiddleware = RetryMiddleware(
    configuration: RetryMiddleware.Configuration(),
    client: httpClient
)

// Aggressive retry settings
let aggressiveRetry = RetryMiddleware.aggressive(client: httpClient)

// Custom jitter strategy
let customRetry = RetryMiddleware.withJitter(
    client: httpClient,
    jitterStrategy: .decorrelated
)

// Full custom configuration
let customRetry = RetryMiddleware(
    configuration: RetryMiddleware.Configuration(
        maxAttempts: 5,
        baseDelay: 1.0,
        maxDelay: 30.0,
        backoffMultiplier: 2.0,
        jitterStrategy: .equal,
        shouldRetry: { error, attempt in
            // Custom retry logic with attempt awareness
            switch error.category {
            case .network: return attempt <= 3
            case .http(let status) where status.rawValue >= 500: return attempt <= 2
            default: return false
            }
        }
    ),
    client: httpClient
)
```

**Jitter Strategies:**
- `none`: Exact exponential backoff
- `full`: Random delay between 0 and calculated backoff
- `equal`: Random delay between half and full backoff
- `decorrelated`: Uses previous delay as base for calculation

## Middleware Composition

Middleware can be composed together in the NetworkClient:

```swift
let client = NetworkClient(
    requestMiddlewares: [
        authMiddleware, // Add authentication headers
        cachingMiddleware // Check cache before request
    ],
    responseMiddlewares: [
        timingMiddleware, // Record timing metrics
        cachingMiddleware // Store response in cache
    ],
    errorMiddlewares: [
        circuitBreaker, // Check circuit state and record failures
        authMiddleware, // Handle auth errors and refresh tokens
        retryMiddleware, // Retry failed requests with backoff
        timingMiddleware // Record error metrics
    ]
)
```

## Swift 6 Compliance

All middleware components are designed for Swift 6 compliance:

- **Sendable Conformance**: All types properly conform to Sendable
- **Actor Usage**: Thread-safe state management using actors where needed
- **Structured Concurrency**: Proper use of async/await throughout
- **Data Race Safety**: No shared mutable state without proper synchronization

## Error Handling

The middleware system integrates with the framework's HTTPError type system:

- **Network Errors**: Connection issues, DNS failures, SSL errors
- **HTTP Errors**: Status code-based errors with request/response context
- **Timeout Errors**: Request timeout handling
- **Custom Errors**: Framework-specific errors (e.g., CircuitBreakerError)

## Performance Considerations

- **Memory Management**: Bounded caches and metric collections
- **Concurrency**: Proper async/await usage prevents blocking
- **Resource Cleanup**: Automatic cleanup of expired entries
- **Backpressure**: Circuit breaker provides natural backpressure

## Extension Points

The middleware architecture is designed for extension:

- **Custom Token Providers**: Implement TokenProvider for different auth schemes
- **Custom Cache Storage**: Implement CacheStorage for different backends
- **Custom Metrics Collectors**: Implement MetricsCollector for different outputs
- **Custom Retry Logic**: Configurable retry conditions and delay calculations

## Testing

Each middleware component includes factory methods for different scenarios:

- **Default configurations** for common use cases
- **Aggressive/Conservative variants** for different requirements
- **Test-friendly constructors** for dependency injection

## Dependencies

The middleware system has minimal dependencies:

- Foundation framework
- Swift 6 concurrency features
- Networking core types (HTTPRequest, HTTPResponse, HTTPError)

## Thread Safety

All middleware components are thread-safe:

- Actors used for mutable state
- Sendable conformance throughout
- Immutable configurations
- Safe concurrent access patterns