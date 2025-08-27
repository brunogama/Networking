# NetworkClient

The primary HTTP client implementation with comprehensive middleware support and declarative configuration.

## Overview

``NetworkClient`` is the main entry point for making HTTP requests in the Networking framework. It provides a powerful, flexible foundation for network communication with support for middleware, caching, authentication, retry logic, and more.

The client is designed around two key principles:
1. **Declarative Configuration**: Use result builders to configure the client in a readable, type-safe way
2. **Middleware Pipeline**: Extend functionality through composable middleware components

## Basic Usage

### Simple Client Creation

Create a basic client for immediate use:

```swift
import Networking

let client = NetworkClient {
    BaseURL("https://api.example.com")
    DefaultTimeout(30.0)
}

let response = try await client.execute {
    GET("/users")
}
```

### Advanced Configuration

Configure a client with middleware and advanced features:

```swift
let client = NetworkClient {
    // Base configuration
    BaseURL("https://api.example.com")
    DefaultTimeout(30.0)
    DefaultHeader("User-Agent", "MyApp/1.0")
    
    // Authentication
    BearerToken("your-api-key")
    
    // Middleware
    EnableRetry {
        MaxAttempts(3)
        BackoffStrategy(.exponential(multiplier: 2.0))
    }
    
    EnableCaching {
        Policy(.standard)
        Storage(.memory(maxSize: .megabytes(50)))
    }
    
    EnableLogging()
    
    // Security
    EnableSecurity {
        CertificatePinning(sha256Hashes: ["abc123..."])
        MinTLSVersion(.v1_2)
    }
}
```

## Architecture

### HTTPClient Protocol

``NetworkClient`` conforms to the ``HTTPClient`` protocol:

```swift
/// Protocol for executing HTTP requests
public protocol HTTPClient: Sendable {
    /// Execute an HTTP request asynchronously
    /// - Parameter request: The request to execute
    /// - Returns: The HTTP response
    /// - Throws: HTTPError on failure
    func execute(_ request: HTTPRequest) async throws -> HTTPResponse
}
```

### Middleware Pipeline

NetworkClient processes requests through a middleware pipeline:

1. **Request Middleware**: Transform requests before execution
2. **Network Execution**: Perform the actual HTTP request
3. **Response Middleware**: Process responses after execution  
4. **Error Middleware**: Handle any errors that occur

```swift
// Middleware processing flow
Request → Request Middleware → Network → Response Middleware → Response
    ↓                                          ↓
Error Middleware ← ← ← ← ← ← ← ← ← ← ← ← ← ← Error
```

## Configuration Components

### Base Configuration

Essential configuration for every client:

```swift
let client = NetworkClient {
    // Required base URL
    BaseURL("https://api.example.com")
    
    // Default request timeout
    DefaultTimeout(30.0)
    
    // Default headers applied to all requests
    DefaultHeader("Accept", "application/json")
    DefaultHeader("User-Agent", "MyApp/1.0")
}
```

### Session Configuration

Customize the underlying URLSession:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    
    Session {
        AllowsCellularAccess(true)
        AllowsExpensiveNetworkAccess(false)
        TimeoutIntervalForRequest(60.0)
        HTTPMaximumConnectionsPerHost(4)
    }
}
```

### Authentication Configuration

Add authentication to all requests:

```swift
// Bearer token authentication
let client = NetworkClient {
    BaseURL("https://api.example.com")
    BearerToken("your-api-key")
}

// Basic authentication
let client = NetworkClient {
    BaseURL("https://api.example.com")
    BasicAuth(username: "user", password: "pass")
}

// Custom authentication
let client = NetworkClient {
    BaseURL("https://api.example.com")
    CustomAuth { request in
        var modifiedRequest = request
        modifiedRequest.headers["X-API-Key"] = "secret-key"
        return modifiedRequest
    }
}
```

## Making Requests

### Using Request Builder

The most flexible way to make requests:

```swift
let response = try await client.execute {
    POST("/api/users")
    Header("Content-Type", "application/json")
    JSONBody(user)
    Timeout(15.0)
}
```

### Direct Request Objects

For programmatic request creation:

```swift
let request = HTTPRequest(
    method: .post,
    url: URL(string: "https://api.example.com/users")!,
    headers: ["Content-Type": "application/json"],
    body: jsonData
)

let response = try await client.execute(request)
```

### Response Processing

Process responses with built-in utilities:

```swift
let response = try await client.execute {
    GET("/api/user/123")
}

// Decode JSON directly
let user: User = try response.decode(User.self)

// Check status
if response.status.isSuccess {
    print("Success!")
} else {
    print("Request failed: \(response.status)")
}

// Access headers
let contentType = response.headers["Content-Type"]
```

## Middleware Integration

### Built-in Middleware

Enable common middleware with simple configuration:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    
    // Enable retry with default settings
    EnableRetry()
    
    // Enable caching with custom policy
    EnableCaching {
        Policy(.aggressive)
        Duration(.hours(2))
    }
    
    // Enable request/response logging
    EnableLogging()
}
```

### Custom Middleware

Add custom middleware for specialized needs:

```swift
// Custom request middleware
struct APIVersionMiddleware: HTTPRequestMiddleware {
    func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
        var modifiedRequest = request
        modifiedRequest.headers["X-API-Version"] = "v2"
        return modifiedRequest
    }
}

// Custom response middleware  
struct TimingMiddleware: HTTPResponseMiddleware {
    func processResponse(_ response: HTTPResponse) async throws -> HTTPResponse {
        let duration = response.headers["X-Response-Time"] ?? "unknown"
        print("Request took: \(duration)ms")
        return response
    }
}

// Add to client
let client = NetworkClient {
    BaseURL("https://api.example.com")
    Middleware(APIVersionMiddleware())
    Middleware(TimingMiddleware())
}
```

## Error Handling

NetworkClient provides comprehensive error handling:

```swift
do {
    let response = try await client.execute {
        GET("/api/protected-resource")
    }
    // Handle success
} catch let error as HTTPError {
    switch error.category {
    case .network(.noConnection):
        // Handle offline scenarios
        print("No internet connection available")
        
    case .http(let status) where status.code == 401:
        // Handle authentication errors
        print("Authentication required")
        
    case .http(let status) where status.isServerError:
        // Handle server errors
        print("Server error: \(status.reasonPhrase)")
        
    case .timeout:
        // Handle timeouts
        print("Request timed out")
        
    default:
        // Handle other errors
        print("Request failed: \(error.userFriendlyDescription)")
    }
}
```

## Concurrency & Thread Safety

NetworkClient is fully thread-safe and designed for concurrent usage:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
}

// Safe to use concurrently
async let user = client.execute { GET("/user/123") }
async let posts = client.execute { GET("/user/123/posts") }
async let comments = client.execute { GET("/user/123/comments") }

let (userResponse, postsResponse, commentsResponse) = try await (user, posts, comments)
```

## Performance Considerations

### Connection Reuse

NetworkClient automatically reuses connections for efficiency:

```swift
// The same client instance will reuse connections
let client = NetworkClient {
    BaseURL("https://api.example.com")
}

// Multiple requests will share connections
for i in 1...10 {
    let response = try await client.execute { GET("/data/\(i)") }
}
```

### Request Coalescing

Avoid duplicate concurrent requests:

```swift
// Instead of multiple concurrent identical requests
Task {
    let response1 = try await client.execute { GET("/expensive-operation") }
}
Task {
    let response2 = try await client.execute { GET("/expensive-operation") }
}

// Consider caching or request deduplication
let client = NetworkClient {
    BaseURL("https://api.example.com")
    EnableCaching {
        Policy(.standard)
        Duration(.minutes(5))
    }
}
```

## Testing Support

NetworkClient is designed to be easily testable:

```swift
// Mock client for testing
class MockHTTPClient: HTTPClient {
    var responses: [HTTPResponse] = []
    
    func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        return responses.removeFirst()
    }
}

// Use in tests
let mockClient = MockHTTPClient()
mockClient.responses = [
    HTTPResponse(request: request, status: .ok, headers: [:], body: testData, url: nil)
]

let response = try await mockClient.execute(testRequest)
```

## Best Practices

### Client Lifecycle

- Create one client instance per base URL/configuration
- Reuse client instances across your application
- Store clients as singletons or dependency injection

### Configuration

- Set appropriate timeouts for your use case
- Configure retry logic for transient failures
- Enable caching for appropriate requests
- Use middleware to avoid repetitive request modifications

### Error Handling

- Always handle HTTPError specifically
- Provide user-friendly error messages
- Implement appropriate retry strategies
- Log detailed error information for debugging

### Performance

- Reuse client instances to benefit from connection pooling
- Configure reasonable timeouts to avoid hanging requests
- Use caching to reduce network traffic
- Monitor performance with observability middleware

## See Also

- ``HTTPClient``
- ``HTTPRequest``
- ``HTTPResponse``
- ``NetworkClientBuilder``
- <doc:ClientConfiguration>
- <doc:MiddlewareOverview>
- <doc:RequestBuilding>
- <doc:ErrorHandling>