# Middleware Overview

Extensible request and response processing pipeline for cross-cutting concerns like authentication, caching, retry logic, and observability.

## Overview

The middleware system in the Networking framework provides a powerful way to process HTTP requests and responses through a composable pipeline. Middleware components can be chained together to handle cross-cutting concerns without cluttering your main request logic.

Key middleware capabilities:
- **Request Processing**: Transform requests before execution
- **Response Processing**: Process responses after execution  
- **Error Handling**: Handle and transform errors
- **Composable Pipeline**: Chain multiple middleware together
- **Built-in Middleware**: Common functionality ready to use
- **Custom Middleware**: Create specialized middleware for your needs

## Middleware Architecture

### Processing Pipeline

Middleware processes requests and responses in a predictable pipeline:

```swift
Request → Middleware Chain → Network → Middleware Chain → Response
    ↓                                          ↓
Error Middleware ← ← ← ← ← ← ← ← ← ← ← ← ← ← Error
```

### Middleware Types

The framework supports different types of middleware:

```swift
/// Process requests before network execution
public protocol HTTPRequestMiddleware: Sendable {
    func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest
}

/// Process responses after network execution
public protocol HTTPResponseMiddleware: Sendable {
    func processResponse(_ response: HTTPResponse) async throws -> HTTPResponse
}

/// Handle errors that occur during request execution
public protocol HTTPErrorMiddleware: Sendable {
    func handleError(_ error: HTTPError) async throws -> HTTPError
}
```

## Built-in Middleware

### Authentication Middleware

Automatically handle authentication for all requests:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    
    // Bearer token authentication
    BearerTokenMiddleware(token: "your-token")
    
    // Basic authentication
    BasicAuthMiddleware(username: "user", password: "pass")
    
    // API key authentication
    APIKeyMiddleware(header: "X-API-Key", key: "your-api-key")
}
```

### Retry Middleware

Automatically retry failed requests with configurable strategies:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    
    EnableRetry {
        MaxAttempts(3)
        BackoffStrategy(.exponential(multiplier: 2.0))
        RetryCondition(.networkErrors)
        RetryCondition(.serverErrors)
    }
}
```

**Retry Strategies:**

```swift
// Exponential backoff: 1s, 2s, 4s, 8s...
BackoffStrategy(.exponential(multiplier: 2.0))

// Linear backoff: 1s, 2s, 3s, 4s...
BackoffStrategy(.linear(increment: 1.0))

// Fixed delay: 5s, 5s, 5s, 5s...
BackoffStrategy(.fixed(delay: 5.0))

// Custom backoff
BackoffStrategy(.custom { attempt in
    Double(attempt * attempt) // Quadratic backoff
})
```

### Caching Middleware

Cache responses to reduce network traffic and improve performance:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    
    EnableCaching {
        // Cache policy
        Policy(.standard)
        Policy(.aggressive)
        Policy(.networkFirst)
        
        // Storage options
        Storage(.memory(maxSize: .megabytes(50)))
        Storage(.disk(maxSize: .megabytes(500)))
        Storage(.hybrid(memorySize: .megabytes(50), diskSize: .megabytes(500)))
        
        // Cache duration
        Duration(.minutes(15))
        Duration(.hours(2))
        Duration(.custom(300))
    }
}
```

### Logging Middleware

Log requests and responses for debugging and monitoring:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    
    EnableLogging {
        // Log level
        Level(.debug)    // Log everything
        Level(.info)     // Log basic request/response info
        Level(.error)    // Log only errors
        
        // Log components
        LogRequests(true)
        LogResponses(true)
        LogHeaders(true)
        LogBodies(false) // Be careful with sensitive data
        
        // Custom logger
        Logger(OSLog.default)
        Logger(CustomLogger())
    }
}
```

### Observability Middleware

Collect metrics and traces for monitoring:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    
    EnableObservability {
        // Metrics collection
        CollectMetrics(true)
        
        // Request timing
        TrackTiming(true)
        
        // Custom metrics handler
        MetricsHandler(CustomMetricsCollector())
        
        // Distributed tracing
        EnableTracing(true)
        TraceHeaders(["X-Trace-ID", "X-Span-ID"])
    }
}
```

## Creating Custom Middleware

### Request Middleware

Transform requests before they're sent:

```swift
// Add API version header to all requests
struct APIVersionMiddleware: HTTPRequestMiddleware {
    let version: String
    
    func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
        var modifiedRequest = request
        modifiedRequest.headers["X-API-Version"] = version
        return modifiedRequest
    }
}

// Rate limiting middleware
struct RateLimitMiddleware: HTTPRequestMiddleware {
    private let rateLimiter: RateLimiter
    
    init(requestsPerSecond: Int) {
        self.rateLimiter = RateLimiter(rate: requestsPerSecond)
    }
    
    func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
        try await rateLimiter.waitForPermission()
        return request
    }
}

// Usage
let client = NetworkClient {
    BaseURL("https://api.example.com")
    Middleware(APIVersionMiddleware(version: "v2"))
    Middleware(RateLimitMiddleware(requestsPerSecond: 10))
}
```

### Response Middleware

Process responses after they're received:

```swift
// Extract and store response timing
struct TimingMiddleware: HTTPResponseMiddleware {
    func processResponse(_ response: HTTPResponse) async throws -> HTTPResponse {
        if let serverTime = response.headers["X-Response-Time"],
           let serverTimeMs = Double(serverTime) {
            print("Server processing time: \(serverTimeMs)ms")
            
            // Store timing data
            await MetricsStore.shared.recordResponseTime(serverTimeMs)
        }
        
        return response
    }
}

// Transform response headers
struct HeaderTransformMiddleware: HTTPResponseMiddleware {
    func processResponse(_ response: HTTPResponse) async throws -> HTTPResponse {
        var modifiedResponse = response
        
        // Normalize header names
        let normalizedHeaders = response.headers.reduce(into: [String: String]()) { result, pair in
            result[pair.key.lowercased()] = pair.value
        }
        
        modifiedResponse.headers = normalizedHeaders
        return modifiedResponse
    }
}
```

### Error Middleware

Handle and transform errors:

```swift
// Automatic token refresh on 401 errors
struct TokenRefreshMiddleware: HTTPErrorMiddleware {
    private let authService: AuthService
    
    init(authService: AuthService) {
        self.authService = authService
    }
    
    func handleError(_ error: HTTPError) async throws -> HTTPError {
        // Check if this is an authentication error
        guard case .http(let status) = error.category,
              status.code == 401 else {
            return error // Not an auth error, pass through
        }
        
        do {
            // Attempt token refresh
            let newToken = try await authService.refreshToken()
            
            // Update the original request with new token
            if var request = error.request {
                request.headers["Authorization"] = "Bearer \(newToken)"
                
                // Create a new error that suggests retry with updated request
                return HTTPError(
                    category: .retryableWithUpdatedRequest(request),
                    userFriendlyDescription: "Authentication refreshed, retrying...",
                    request: request,
                    response: error.response
                )
            }
        } catch {
            // Token refresh failed, convert to authentication required error
            return HTTPError(
                category: .authenticationRequired,
                userFriendlyDescription: "Please log in again",
                request: error.request,
                response: error.response
            )
        }
        
        return error
    }
}

// Circuit breaker error middleware
struct CircuitBreakerMiddleware: HTTPErrorMiddleware {
    private let circuitBreaker: CircuitBreaker
    
    init(failureThreshold: Int = 5, recoveryTime: TimeInterval = 30) {
        self.circuitBreaker = CircuitBreaker(
            failureThreshold: failureThreshold,
            recoveryTime: recoveryTime
        )
    }
    
    func handleError(_ error: HTTPError) async throws -> HTTPError {
        // Record the failure
        await circuitBreaker.recordFailure()
        
        // Check if circuit should be opened
        if await circuitBreaker.shouldReject() {
            return HTTPError(
                category: .circuitBreakerOpen,
                userFriendlyDescription: "Service temporarily unavailable",
                request: error.request,
                response: error.response
            )
        }
        
        return error
    }
}
```

## Middleware Composition

### Middleware Ordering

Middleware execution order matters. Request middleware executes in the order they're added, response middleware executes in reverse order:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    
    // Request middleware (executes in this order)
    Middleware(AuthenticationMiddleware())   // 1st
    Middleware(RateLimitMiddleware())        // 2nd  
    Middleware(LoggingMiddleware())          // 3rd
    
    // Response middleware (executes in reverse order)
    // LoggingMiddleware processes response first
    // RateLimitMiddleware processes response second
    // AuthenticationMiddleware processes response last
}
```

### Conditional Middleware

Apply middleware based on conditions:

```swift
struct ConditionalMiddleware<T: HTTPRequestMiddleware>: HTTPRequestMiddleware {
    let middleware: T
    let condition: () -> Bool
    
    func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
        if condition() {
            return try await middleware.modifyRequest(request)
        }
        return request
    }
}

// Usage
let client = NetworkClient {
    BaseURL("https://api.example.com")
    
    // Only apply debug middleware in debug builds
    Middleware(ConditionalMiddleware(
        middleware: DebugHeadersMiddleware(),
        condition: { 
            #if DEBUG
            return true
            #else
            return false
            #endif
        }
    ))
}
```

### Middleware Groups

Create reusable middleware combinations:

```swift
// Production middleware stack
@MiddlewareBuilder
func productionMiddleware(apiKey: String) -> [Middleware] {
    APIKeyMiddleware(key: apiKey)
    
    EnableRetry {
        MaxAttempts(3)
        BackoffStrategy(.exponential(multiplier: 2.0))
    }
    
    EnableCaching {
        Policy(.standard)
        Duration(.minutes(15))
    }
    
    EnableObservability {
        CollectMetrics(true)
        TrackTiming(true)
    }
}

// Development middleware stack
@MiddlewareBuilder  
func developmentMiddleware(apiKey: String) -> [Middleware] {
    APIKeyMiddleware(key: apiKey)
    
    EnableLogging {
        Level(.debug)
        LogRequests(true)
        LogResponses(true)
        LogHeaders(true)
    }
    
    EnableRetry {
        MaxAttempts(1) // Less aggressive retry in development
    }
}

// Usage
let client = NetworkClient {
    BaseURL("https://api.example.com")
    
    #if DEBUG
    developmentMiddleware(apiKey: "dev-key")
    #else
    productionMiddleware(apiKey: "prod-key")
    #endif
}
```

## Advanced Middleware Patterns

### Stateful Middleware

Middleware that maintains state between requests:

```swift
actor RequestCounterMiddleware: HTTPRequestMiddleware {
    private var requestCount = 0
    
    func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
        requestCount += 1
        
        var modifiedRequest = request
        modifiedRequest.headers["X-Request-Count"] = "\(requestCount)"
        return modifiedRequest
    }
    
    func getRequestCount() async -> Int {
        return requestCount
    }
}
```

### Middleware with Dependencies

Middleware that depends on external services:

```swift
class MetricsMiddleware: HTTPResponseMiddleware {
    private let metricsService: MetricsService
    private let configuration: MetricsConfiguration
    
    init(metricsService: MetricsService, configuration: MetricsConfiguration) {
        self.metricsService = metricsService
        self.configuration = configuration
    }
    
    func processResponse(_ response: HTTPResponse) async throws -> HTTPResponse {
        // Collect metrics based on configuration
        if configuration.trackResponseTimes {
            await metricsService.recordResponseTime(response.requestDuration)
        }
        
        if configuration.trackStatusCodes {
            await metricsService.recordStatusCode(response.status.code)
        }
        
        if configuration.trackErrorRates && !response.status.isSuccess {
            await metricsService.recordError(response.status.code)
        }
        
        return response
    }
}
```

### Middleware Factories

Create middleware based on configuration:

```swift
enum MiddlewareFactory {
    static func createAuthenticationMiddleware(
        for environment: Environment,
        with credentials: Credentials
    ) -> HTTPRequestMiddleware {
        switch environment {
        case .development:
            return MockAuthMiddleware(mockToken: "dev-token")
        case .staging:
            return BasicAuthMiddleware(
                username: credentials.username,
                password: credentials.password
            )
        case .production:
            return BearerTokenMiddleware(token: credentials.accessToken)
        }
    }
    
    static func createRetryMiddleware(
        for environment: Environment
    ) -> RetryMiddleware {
        switch environment {
        case .development:
            return RetryMiddleware(maxAttempts: 1) // No retry in dev
        case .staging:
            return RetryMiddleware(
                maxAttempts: 2,
                backoffStrategy: .linear(increment: 1.0)
            )
        case .production:
            return RetryMiddleware(
                maxAttempts: 3,
                backoffStrategy: .exponential(multiplier: 2.0)
            )
        }
    }
}
```

## Middleware Testing

### Testing Individual Middleware

```swift
@Test func testAPIVersionMiddleware() async throws {
    let middleware = APIVersionMiddleware(version: "v2")
    let originalRequest = HTTPRequest(method: .get, url: URL(string: "https://api.example.com/data")!)
    
    let modifiedRequest = try await middleware.modifyRequest(originalRequest)
    
    #expect(modifiedRequest.headers["X-API-Version"] == "v2")
}

@Test func testTimingMiddleware() async throws {
    let middleware = TimingMiddleware()
    let response = HTTPResponse(
        request: HTTPRequest(method: .get, url: URL(string: "https://api.example.com")!),
        status: .ok,
        headers: ["X-Response-Time": "150"],
        body: nil,
        url: nil
    )
    
    let processedResponse = try await middleware.processResponse(response)
    
    // Verify timing was recorded
    let recordedTime = await MetricsStore.shared.getLastRecordedTime()
    #expect(recordedTime == 150.0)
}
```

### Integration Testing

Test middleware in combination:

```swift
@Test func testMiddlewareIntegration() async throws {
    let client = NetworkClient {
        BaseURL("https://httpbin.org")
        Middleware(APIVersionMiddleware(version: "v1"))
        Middleware(AuthHeaderMiddleware(token: "test-token"))
    }
    
    let response = try await client.execute {
        GET("/headers")
    }
    
    // Verify both middleware effects are present
    let responseData = try response.decode([String: Any].self)
    let headers = responseData["headers"] as? [String: String]
    
    #expect(headers?["X-Api-Version"] == "v1")
    #expect(headers?["Authorization"] == "Bearer test-token")
}
```

## Best Practices

### Middleware Design Guidelines

**Single Responsibility:**
- Each middleware should handle one specific concern
- Avoid combining unrelated functionality in one middleware
- Keep middleware focused and testable

**Performance Considerations:**
- Minimize processing in middleware hot paths
- Use async operations efficiently
- Cache expensive computations when possible
- Avoid blocking operations in middleware

**Error Handling:**
- Middleware should handle their own errors gracefully
- Propagate errors that can't be handled
- Provide meaningful error messages and recovery suggestions

**State Management:**
- Prefer stateless middleware when possible
- Use actors for thread-safe stateful middleware
- Consider the lifecycle of stateful middleware

### Middleware Organization

```swift
// Group related middleware in extensions
extension NetworkClientBuilder {
    func withStandardMiddleware(apiKey: String) -> Self {
        self
            .middleware(APIKeyMiddleware(key: apiKey))
            .middleware(RetryMiddleware(maxAttempts: 3))
            .middleware(CachingMiddleware(duration: .minutes(15)))
    }
    
    func withObservability() -> Self {
        self
            .middleware(LoggingMiddleware(level: .info))
            .middleware(MetricsMiddleware())
            .middleware(TracingMiddleware())
    }
}
```

## See Also

- ``HTTPRequestMiddleware``
- ``HTTPResponseMiddleware``
- ``HTTPErrorMiddleware``
- ``NetworkClient``
- <doc:MIDDLEWARE_DOCUMENTATION>
- <doc:ADVANCED_USAGE>
- <doc:NetworkClient>