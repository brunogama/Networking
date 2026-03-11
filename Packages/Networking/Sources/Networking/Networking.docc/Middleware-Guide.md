# Middleware Guide

Creating and configuring middleware for request/response processing.

## Overview

Networking's middleware system provides a powerful way to intercept and modify HTTP requests and responses. Middleware enables cross-cutting concerns like authentication, logging, caching, retry logic, and custom transformations.

## Middleware Types

The framework provides three types of middleware:

- **Request Middleware**: Modifies requests before execution
- **Response Middleware**: Processes responses after execution  
- **Error Middleware**: Handles errors and provides recovery strategies

## Request Middleware

### HTTPRequestMiddleware Protocol

Implement ``HTTPRequestMiddleware`` to modify requests:

```swift
public protocol HTTPRequestMiddleware: Sendable {
    func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest
}
```

### Example: API Version Header

Add an API version header to all requests:

```swift
struct APIVersionMiddleware: HTTPRequestMiddleware {
    private let version: String
    
    init(version: String) {
        self.version = version
    }
    
    func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
        var headers = request.headers
        headers["X-API-Version"] = version
        
        return HTTPRequest(
            method: request.method,
            url: request.url,
            headers: headers,
            body: request.body,
            timeout: request.timeout
        )
    }
}

// Usage
let client = NetworkClient(
    requestMiddlewares: [APIVersionMiddleware(version: "v2")]
)
```

### Example: Request ID Generation

Add unique request IDs for tracing:

```swift
struct RequestIDMiddleware: HTTPRequestMiddleware {
    func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
        var headers = request.headers
        headers["X-Request-ID"] = UUID().uuidString
        
        return HTTPRequest(
            method: request.method,
            url: request.url,
            headers: headers,
            body: request.body,
            timeout: request.timeout
        )
    }
}
```

### Example: Request Validation

Validate requests before sending:

```swift
struct RequestValidationMiddleware: HTTPRequestMiddleware {
    func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
        // Validate URL
        guard request.url.scheme == "https" else {
            throw HTTPError(
                category: .configuration("Only HTTPS URLs are allowed"),
                request: request
            )
        }
        
        // Validate required headers
        guard request.headers["Authorization"] != nil else {
            throw HTTPError(
                category: .configuration("Authorization header is required"),
                request: request
            )
        }
        
        return request
    }
}
```

## Response Middleware

### HTTPResponseMiddleware Protocol

Implement ``HTTPResponseMiddleware`` to process responses:

```swift
public protocol HTTPResponseMiddleware: Sendable {
    func processResponse(
        _ response: HTTPResponse,
        for request: HTTPRequest
    ) async throws -> HTTPResponse
}
```

### Example: Response Validation

Validate response status and content:

```swift
struct ResponseValidationMiddleware: HTTPResponseMiddleware {
    func processResponse(
        _ response: HTTPResponse,
        for request: HTTPRequest
    ) async throws -> HTTPResponse {
        // Check for success status
        guard response.status.isSuccess else {
            throw HTTPError(
                category: .http(response.status),
                request: request,
                response: response
            )
        }
        
        // Validate content type for JSON endpoints
        if request.url.path.contains("/api/") {
            let contentType = response.headers["Content-Type"]
            guard contentType?.contains("application/json") == true else {
                throw HTTPError(
                    category: .decoding("Expected JSON content type"),
                    request: request,
                    response: response
                )
            }
        }
        
        return response
    }
}
```

### Example: Response Transformation

Transform response data:

```swift
struct ResponseTransformationMiddleware: HTTPResponseMiddleware {
    func processResponse(
        _ response: HTTPResponse,
        for request: HTTPRequest
    ) async throws -> HTTPResponse {
        guard let body = response.body,
              let jsonObject = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let data = jsonObject["data"] else {
            return response
        }
        
        // Extract nested data and create new response
        let transformedData = try JSONSerialization.data(withJSONObject: data)
        
        return HTTPResponse(
            request: response.request,
            status: response.status,
            headers: response.headers,
            body: transformedData
        )
    }
}
```

### Example: Metrics Collection

Collect response metrics:

```swift
struct MetricsCollectionMiddleware: HTTPResponseMiddleware {
    private let metricsCollector: MetricsCollector
    
    init(metricsCollector: MetricsCollector) {
        self.metricsCollector = metricsCollector
    }
    
    func processResponse(
        _ response: HTTPResponse,
        for request: HTTPRequest
    ) async throws -> HTTPResponse {
        let endTime = Date()
        
        await metricsCollector.recordHTTPRequest(
            method: request.method.rawValue,
            path: request.url.path,
            statusCode: response.status.rawValue,
            duration: endTime.timeIntervalSince(request.startTime),
            responseSize: response.body?.count ?? 0
        )
        
        return response
    }
}
```

## Error Middleware

### HTTPErrorMiddleware Protocol

Implement ``HTTPErrorMiddleware`` to handle errors:

```swift
public protocol HTTPErrorMiddleware: Sendable {
    func handleError(
        _ error: HTTPError,
        for request: HTTPRequest
    ) async throws -> HTTPResponse
}
```

### Example: Token Refresh

Automatically refresh expired tokens:

```swift
struct TokenRefreshMiddleware: HTTPErrorMiddleware {
    private let tokenProvider: BearerTokenProvider
    private let client: HTTPClient
    
    init(tokenProvider: BearerTokenProvider, client: HTTPClient) {
        self.tokenProvider = tokenProvider
        self.client = client
    }
    
    func handleError(
        _ error: HTTPError,
        for request: HTTPRequest
    ) async throws -> HTTPResponse {
        // Check if this is an authentication error
        guard case .http(let status) = error.category,
              status == .unauthorized else {
            throw error
        }
        
        // Attempt to refresh the token
        do {
            let newToken = try await tokenProvider.refreshToken()
            
            // Retry the request with the new token
            var headers = request.headers
            headers["Authorization"] = "Bearer \(newToken)"
            
            let retryRequest = HTTPRequest(
                method: request.method,
                url: request.url,
                headers: headers,
                body: request.body,
                timeout: request.timeout
            )
            
            return try await client.execute(retryRequest)
        } catch {
            throw HTTPError(
                category: .configuration("Token refresh failed"),
                request: request,
                underlyingError: error
            )
        }
    }
}
```

### Example: Fallback Response

Provide fallback responses for certain errors:

```swift
struct FallbackResponseMiddleware: HTTPErrorMiddleware {
    private let fallbackData: [String: Data]
    
    init(fallbackData: [String: Data]) {
        self.fallbackData = fallbackData
    }
    
    func handleError(
        _ error: HTTPError,
        for request: HTTPRequest
    ) async throws -> HTTPResponse {
        // Only provide fallback for network errors on GET requests
        guard request.method == .get,
              case .network = error.category,
              let fallbackBody = fallbackData[request.url.path] else {
            throw error
        }
        
        // Return cached/fallback response
        return HTTPResponse(
            request: request,
            status: .ok,
            headers: [
                "Content-Type": "application/json",
                "X-Fallback": "true"
            ],
            body: fallbackBody
        )
    }
}
```

## Combining Multiple Middleware

### Middleware Pipeline

Middleware executes in a specific order:

1. Request middleware (in order of registration)
2. Network request execution
3. Response middleware (in order of registration)
4. Error middleware (if an error occurs, in order of registration)

```swift
let client = NetworkClient(
    requestMiddlewares: [
        RequestIDMiddleware(),
        APIVersionMiddleware(version: "v2"),
        AuthenticationMiddleware(),
        RequestValidationMiddleware()
    ],
    responseMiddlewares: [
        MetricsCollectionMiddleware(metricsCollector),
        ResponseValidationMiddleware(),
        ResponseTransformationMiddleware()
    ],
    errorMiddlewares: [
        TokenRefreshMiddleware(tokenProvider, client),
        RetryMiddleware(configuration: retryConfig),
        FallbackResponseMiddleware(fallbackData)
    ]
)
```

## Built-in Middleware

Networking includes several built-in middleware implementations:

### LoggingMiddleware

Logs requests, responses, and errors:

```swift
let loggingMiddleware = LoggingMiddleware(
    configuration: LoggingMiddleware.Configuration(
        level: .detailed,
        includeHeaders: true,
        includeBody: true,
        redactedHeaders: ["Authorization", "X-API-Key"]
    )
)
```

### AuthenticationMiddleware

Handles token-based authentication:

```swift
let authMiddleware = AuthenticationMiddleware(
    configuration: AuthenticationMiddleware.Configuration(
        authorizationHeaderName: "Authorization",
        tokenPrefix: "Bearer ",
        maxRefreshAttempts: 3
    ),
    tokenProvider: tokenProvider,
    client: client
)
```

### RetryMiddleware

Implements retry logic with backoff:

```swift
let retryMiddleware = RetryMiddleware(
    configuration: RetryMiddleware.Configuration(
        maxAttempts: 3,
        backoffStrategy: .exponential,
        retryCondition: { error in
            error.isRetryable
        }
    ),
    client: client
)
```

### CachingMiddleware

Provides response caching:

```swift
let cachingMiddleware = CachingMiddleware(
    configuration: CachingMiddleware.Configuration(
        policy: .standard,
        storage: .memory(size: .MB(50)),
        duration: .ttl(300)
    )
)
```

## Custom Middleware Patterns

### Conditional Middleware

Middleware that only applies to certain requests:

```swift
struct ConditionalMiddleware<T: HTTPRequestMiddleware>: HTTPRequestMiddleware {
    private let condition: (HTTPRequest) -> Bool
    private let middleware: T
    
    init(condition: @escaping (HTTPRequest) -> Bool, middleware: T) {
        self.condition = condition
        self.middleware = middleware
    }
    
    func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
        guard condition(request) else { return request }
        return try await middleware.modifyRequest(request)
    }
}

// Usage: Only apply API versioning to API endpoints
let conditionalVersioning = ConditionalMiddleware(
    condition: { $0.url.path.hasPrefix("/api/") },
    middleware: APIVersionMiddleware(version: "v2")
)
```

### Composite Middleware

Combine multiple middleware into one:

```swift
struct CompositeRequestMiddleware: HTTPRequestMiddleware {
    private let middlewares: [any HTTPRequestMiddleware]
    
    init(middlewares: [any HTTPRequestMiddleware]) {
        self.middlewares = middlewares
    }
    
    func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
        var currentRequest = request
        
        for middleware in middlewares {
            currentRequest = try await middleware.modifyRequest(currentRequest)
        }
        
        return currentRequest
    }
}
```

### State-Preserving Middleware

Middleware that maintains state across requests:

```swift
actor StatefulMiddleware: HTTPRequestMiddleware, HTTPResponseMiddleware {
    private var requestCount = 0
    private var totalResponseTime: TimeInterval = 0
    
    func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
        requestCount += 1
        
        var headers = request.headers
        headers["X-Request-Count"] = "\(requestCount)"
        
        return HTTPRequest(
            method: request.method,
            url: request.url,
            headers: headers,
            body: request.body,
            timeout: request.timeout
        )
    }
    
    func processResponse(
        _ response: HTTPResponse,
        for request: HTTPRequest
    ) async throws -> HTTPResponse {
        if let responseTimeHeader = response.headers["X-Response-Time"],
           let responseTime = TimeInterval(responseTimeHeader) {
            totalResponseTime += responseTime
        }
        
        return response
    }
    
    func getAverageResponseTime() async -> TimeInterval {
        guard requestCount > 0 else { return 0 }
        return totalResponseTime / TimeInterval(requestCount)
    }
}
```

## Middleware Best Practices

### 1. Keep Middleware Focused

Each middleware should have a single responsibility:

```swift
// Good: Focused on one concern
struct AuthorizationMiddleware: HTTPRequestMiddleware { ... }

// Bad: Multiple concerns
struct AuthAndLoggingMiddleware: HTTPRequestMiddleware { ... }
```

### 2. Handle Errors Gracefully

Always provide meaningful error messages:

```swift
func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
    guard let apiKey = configuration.apiKey else {
        throw HTTPError(
            category: .configuration("API key is required but not configured"),
            request: request
        )
    }
    // ... rest of implementation
}
```

### 3. Use Sendable Types

Ensure thread safety with Sendable compliance:

```swift
struct ThreadSafeMiddleware: HTTPRequestMiddleware, Sendable {
    private let configuration: Configuration // Must be Sendable
    
    init(configuration: Configuration) {
        self.configuration = configuration
    }
}
```

### 4. Document Middleware Behavior

Clearly document what your middleware does:

```swift
/// Adds rate limiting headers to requests and enforces rate limits.
///
/// This middleware tracks request rates per endpoint and adds the following headers:
/// - `X-RateLimit-Limit`: Maximum requests per time window
/// - `X-RateLimit-Remaining`: Remaining requests in current window  
/// - `X-RateLimit-Reset`: Unix timestamp when limit resets
///
/// If the rate limit is exceeded, throws an HTTPError with category `.configuration`.
struct RateLimitingMiddleware: HTTPRequestMiddleware {
    // Implementation...
}
```

## Testing Middleware

### Unit Testing

Test middleware in isolation:

```swift
@Test("API version middleware adds correct header")
func testAPIVersionMiddleware() async throws {
    let middleware = APIVersionMiddleware(version: "v2")
    let request = HTTPRequest(
        method: .get,
        url: URL(string: "https://api.example.com/users")!
    )
    
    let modifiedRequest = try await middleware.modifyRequest(request)
    
    #expect(modifiedRequest.headers["X-API-Version"] == "v2")
}
```

### Integration Testing

Test middleware in a full client pipeline:

```swift
@Test("Authentication middleware handles token refresh")
func testAuthenticationFlow() async throws {
    let mockTokenProvider = MockTokenProvider()
    let authMiddleware = AuthenticationMiddleware(
        tokenProvider: mockTokenProvider,
        client: mockClient
    )
    
    let client = NetworkClient(
        requestMiddlewares: [authMiddleware],
        errorMiddlewares: [authMiddleware]
    )
    
    // Test scenarios...
}
```

## Related Topics

- <doc:Client-Configuration>: Configuring middleware through the DSL
- <doc:Authentication>: Built-in authentication middleware
- <doc:Caching-System>: Response caching middleware
- <doc:Error-Handling>: Error recovery strategies