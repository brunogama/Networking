# Core Networking

Fundamental HTTP networking components and protocols.

## Overview

The core networking layer provides the foundation for all HTTP operations in Networking. This includes HTTP primitives, client protocols, and middleware interfaces.

## HTTP Primitives

### HTTPRequest

``HTTPRequest`` represents an HTTP request with all necessary components:

```swift
public struct HTTPRequest: Sendable, Identifiable {
    public let id: UUID
    public let method: HTTPMethod
    public let url: URL
    public let headers: [String: String]
    public let body: Data?
    public let timeout: TimeInterval
}
```

**Key Features:**
- Immutable value type with `Sendable` compliance
- Unique identifier for tracking and debugging
- Complete header and body support
- Configurable timeout per request

**Usage:**
```swift
let request = HTTPRequest(
    method: .get,
    url: URL(string: "https://api.example.com/users")!,
    headers: ["Accept": "application/json"],
    timeout: 30.0
)
```

### HTTPResponse

``HTTPResponse`` encapsulates HTTP response data:

```swift
public struct HTTPResponse: Sendable {
    public let request: HTTPRequest
    public let status: HTTPStatus
    public let headers: [String: String]
    public let body: Data?
}
```

**Key Features:**
- Reference to original request for context
- Structured status code handling
- Case-insensitive header access
- Optional body data

**Usage:**
```swift
// Status code checking
if response.status.isSuccess {
    let data = response.body
}

// Header access
let contentType = response.headers["Content-Type"]

// JSON decoding
let user: User = try response.decode(User.self)
```

### HTTPMethod

``HTTPMethod`` provides a type-safe representation of HTTP methods:

```swift
public struct HTTPMethod: Sendable, Hashable, ExpressibleByStringLiteral {
    public static let get = HTTPMethod("GET")
    public static let post = HTTPMethod("POST")
    public static let put = HTTPMethod("PUT")
    public static let delete = HTTPMethod("DELETE")
    public static let patch = HTTPMethod("PATCH")
    public static let head = HTTPMethod("HEAD")
    public static let options = HTTPMethod("OPTIONS")
}
```

**Features:**
- Predefined common methods
- String literal initialization for custom methods
- Hash and equality support for collections

### HTTPStatus

``HTTPStatus`` represents HTTP status codes with semantic meaning:

```swift
public struct HTTPStatus: Sendable, Hashable, ExpressibleByIntegerLiteral {
    public let rawValue: Int
    
    // Common status codes
    public static let ok = HTTPStatus(200)
    public static let created = HTTPStatus(201)
    public static let badRequest = HTTPStatus(400)
    public static let unauthorized = HTTPStatus(401)
    public static let notFound = HTTPStatus(404)
    public static let internalServerError = HTTPStatus(500)
}
```

**Properties:**
- `isSuccess`: 2xx status codes
- `isRedirection`: 3xx status codes  
- `isClientError`: 4xx status codes
- `isServerError`: 5xx status codes

## Client Protocol

### HTTPClient

``HTTPClient`` is the core protocol for executing HTTP requests:

```swift
public protocol HTTPClient: Sendable {
    func execute(_ request: HTTPRequest) async throws -> HTTPResponse
}
```

**Implementation:**
The primary implementation is ``NetworkClient``, which provides:
- Middleware pipeline processing
- Connection pooling and management
- Error handling and recovery
- Concurrent request execution

```swift
let client: HTTPClient = NetworkClient()
let response = try await client.execute(request)
```

## Middleware Protocols

### HTTPRequestMiddleware

Process and modify requests before execution:

```swift
public protocol HTTPRequestMiddleware: Sendable {
    func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest
}
```

**Common Use Cases:**
- Adding authentication headers
- Request logging and metrics
- Request transformation and validation
- Base URL resolution

### HTTPResponseMiddleware

Process responses after execution:

```swift
public protocol HTTPResponseMiddleware: Sendable {
    func processResponse(
        _ response: HTTPResponse,
        for request: HTTPRequest
    ) async throws -> HTTPResponse
}
```

**Common Use Cases:**
- Response caching
- Response validation
- Metrics collection
- Response transformation

### HTTPErrorMiddleware

Handle errors and provide recovery strategies:

```swift
public protocol HTTPErrorMiddleware: Sendable {
    func handleError(
        _ error: HTTPError,
        for request: HTTPRequest
    ) async throws -> HTTPResponse
}
```

**Common Use Cases:**
- Retry logic for transient failures
- Authentication token refresh
- Circuit breaker patterns
- Error recovery strategies

## Error Handling

### HTTPError

``HTTPError`` provides comprehensive error categorization:

```swift
public struct HTTPError: Error, Sendable, LocalizedError {
    public let category: Category
    public let request: HTTPRequest?
    public let response: HTTPResponse?
    public let underlyingError: Error?
}
```

**Error Categories:**
- `.network(NetworkError)`: Network-level failures
- `.http(HTTPStatus)`: HTTP status code errors
- `.decoding(String)`: JSON/data decoding failures
- `.encoding(String)`: Request encoding failures
- `.timeout`: Request timeout
- `.cancelled`: Request cancellation
- `.configuration(String)`: Configuration errors

**Network Error Types:**
- `.noConnection`: No internet connection
- `.dnsFailure`: DNS resolution failed
- `.connectionLost`: Connection dropped
- `.serverUnreachable`: Server not responding
- `.sslError`: SSL/TLS errors

## Concurrency and Thread Safety

All core networking components are designed for Swift's structured concurrency:

- **Sendable Compliance**: All types conform to `Sendable` for safe concurrent access
- **Actor Isolation**: Internal state uses actors where appropriate
- **Structured Concurrency**: Full support for async/await and TaskGroup operations
- **Cancellation**: Proper cancellation handling throughout the stack

## Performance Considerations

### Connection Management
- Connection pooling and reuse
- HTTP/2 support when available  
- Configurable connection limits

### Memory Management
- Streaming support for large responses
- Automatic memory pressure handling
- Configurable buffer sizes

### Optimization
- Request/response compression
- Keep-alive connections
- DNS caching and resolution optimization

## Related Topics

- <doc:Request-Building>: Building HTTP requests with the fluent API
- <doc:Response-Processing>: Processing and transforming responses
- <doc:Middleware-System>: Creating custom middleware
- <doc:Error-Handling>: Comprehensive error handling strategies