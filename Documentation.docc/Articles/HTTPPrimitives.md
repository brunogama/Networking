# HTTP Primitives

Fundamental types that represent HTTP requests, responses, and related concepts.

## Overview

The Networking framework provides a set of core types that represent HTTP concepts in a Swift-native way. These primitives form the foundation for all networking operations and are designed to be type-safe, performant, and easy to work with.

## Core Types

### HTTPRequest

``HTTPRequest`` represents an HTTP request with all its components:

```swift
/// A complete HTTP request representation
public struct HTTPRequest: Sendable, Equatable, Hashable {
    /// Unique identifier for the request
    public let id: UUID
    
    /// HTTP method (GET, POST, etc.)
    public let method: HTTPMethod
    
    /// Target URL
    public let url: URL
    
    /// Request headers
    public let headers: [String: String]
    
    /// Request body data
    public let body: Data?
    
    /// Request timeout interval
    public let timeout: TimeInterval
}
```

**Creating HTTPRequest instances:**

```swift
// Simple GET request
let request = HTTPRequest(
    method: .get,
    url: URL(string: "https://api.example.com/users")!
)

// POST request with body and headers
let request = HTTPRequest(
    method: .post,
    url: URL(string: "https://api.example.com/users")!,
    headers: ["Content-Type": "application/json"],
    body: jsonData,
    timeout: 30.0
)

// Using the request builder DSL
let request = HTTPRequest {
    POST("/api/users")
    Header("Content-Type", "application/json") 
    JSONBody(user)
    Timeout(30.0)
}
```

### HTTPResponse

``HTTPResponse`` represents an HTTP response with all received data:

```swift
/// A complete HTTP response representation
public struct HTTPResponse: Sendable, Equatable {
    /// The original request that generated this response
    public let request: HTTPRequest
    
    /// HTTP status code and reason phrase
    public let status: HTTPStatus
    
    /// Response headers
    public let headers: [String: String]
    
    /// Response body data
    public let body: Data?
    
    /// Final URL after redirects
    public let url: URL?
}
```

**Working with HTTPResponse:**

```swift
let response = try await client.execute(request)

// Check status
if response.status.isSuccess {
    print("Request succeeded: \(response.status)")
}

// Access headers
let contentType = response.headers["Content-Type"]
let contentLength = response.headers["Content-Length"]

// Decode JSON response
struct User: Codable {
    let id: Int
    let name: String
}

let user: User = try response.decode(User.self)
```

### HTTPMethod

``HTTPMethod`` represents HTTP request methods in a type-safe way:

```swift
/// HTTP request methods
public struct HTTPMethod: Sendable, Equatable, Hashable, CustomStringConvertible {
    public let rawValue: String
    
    // Standard HTTP methods
    public static let get = HTTPMethod("GET")
    public static let post = HTTPMethod("POST")
    public static let put = HTTPMethod("PUT")
    public static let delete = HTTPMethod("DELETE")
    public static let patch = HTTPMethod("PATCH")
    public static let head = HTTPMethod("HEAD")
    public static let options = HTTPMethod("OPTIONS")
    public static let trace = HTTPMethod("TRACE")
    public static let connect = HTTPMethod("CONNECT")
}
```

**Using HTTPMethod:**

```swift
// Using predefined methods
let request = HTTPRequest(method: .post, url: url)

// Custom methods
let customMethod = HTTPMethod("PATCH")
let request = HTTPRequest(method: customMethod, url: url)

// Method properties
print(HTTPMethod.get.rawValue) // "GET"
print(HTTPMethod.post.description) // "POST"
```

### HTTPStatus

``HTTPStatus`` provides structured access to HTTP status codes:

```swift
/// HTTP status code with associated reason phrase and category information
public struct HTTPStatus: Sendable, Equatable, Hashable, CustomStringConvertible {
    /// The numeric status code
    public let code: Int
    
    /// The reason phrase (e.g., "OK", "Not Found")
    public let reasonPhrase: String
    
    /// Whether this is a successful status (2xx)
    public var isSuccess: Bool { code >= 200 && code < 300 }
    
    /// Whether this is a client error (4xx)
    public var isClientError: Bool { code >= 400 && code < 500 }
    
    /// Whether this is a server error (5xx)
    public var isServerError: Bool { code >= 500 && code < 600 }
    
    /// Whether this is a redirection (3xx)
    public var isRedirection: Bool { code >= 300 && code < 400 }
}
```

**Common status codes:**

```swift
// Success codes
HTTPStatus.ok                    // 200 OK
HTTPStatus.created               // 201 Created
HTTPStatus.accepted              // 202 Accepted
HTTPStatus.noContent             // 204 No Content

// Client error codes
HTTPStatus.badRequest            // 400 Bad Request
HTTPStatus.unauthorized          // 401 Unauthorized
HTTPStatus.forbidden             // 403 Forbidden
HTTPStatus.notFound              // 404 Not Found
HTTPStatus.methodNotAllowed      // 405 Method Not Allowed
HTTPStatus.requestTimeout        // 408 Request Timeout
HTTPStatus.conflict              // 409 Conflict
HTTPStatus.unprocessableEntity   // 422 Unprocessable Entity
HTTPStatus.tooManyRequests       // 429 Too Many Requests

// Server error codes
HTTPStatus.internalServerError   // 500 Internal Server Error
HTTPStatus.badGateway           // 502 Bad Gateway
HTTPStatus.serviceUnavailable   // 503 Service Unavailable
HTTPStatus.gatewayTimeout       // 504 Gateway Timeout
```

**Working with HTTPStatus:**

```swift
let response = try await client.execute(request)

switch response.status.code {
case 200:
    print("Success!")
case 401:
    print("Authentication required")
case 404:
    print("Resource not found")
case 500..<600:
    print("Server error: \(response.status.reasonPhrase)")
default:
    print("Unexpected status: \(response.status)")
}

// Using convenience properties
if response.status.isSuccess {
    // Handle success
} else if response.status.isClientError {
    // Handle client-side issues
} else if response.status.isServerError {
    // Handle server-side issues
}
```

### HTTPError

``HTTPError`` provides comprehensive error information with recovery suggestions:

```swift
/// Comprehensive HTTP error with categorization and recovery information
public struct HTTPError: Error, Sendable, LocalizedError, CustomStringConvertible {
    /// Error category (network, HTTP, encoding, etc.)
    public let category: Category
    
    /// Error severity level
    public var severity: ErrorSeverity { category.severity }
    
    /// Whether this error is recoverable
    public var recoveryCategory: RecoveryCategory { category.recoveryCategory }
    
    /// User-friendly error description
    public var userFriendlyDescription: String
    
    /// Actionable recovery suggestions
    public var recoverySuggestions: [String]
    
    /// The request that caused this error
    public let request: HTTPRequest?
    
    /// The response that contained the error (if available)
    public let response: HTTPResponse?
}
```

**Error categories:**

```swift
public enum Category: Sendable, Equatable {
    case network(NetworkError)    // Connection issues, DNS failures
    case http(HTTPStatus)         // HTTP status errors (4xx, 5xx)
    case encoding(String)         // Request encoding failures
    case decoding(String)         // Response decoding failures
    case timeout                  // Request timeout
    case invalidURL(String)       // Malformed URLs
    case cancelled                // Request was cancelled
    case unknown(String)          // Unexpected errors
}
```

**Error handling patterns:**

```swift
do {
    let response = try await client.execute(request)
    // Handle success
} catch let error as HTTPError {
    // Log technical details
    logger.error("Request failed: \(error.description)")
    
    // Show user-friendly message
    showAlert(title: "Error", message: error.userFriendlyDescription)
    
    // Handle specific error types
    switch error.category {
    case .network(.noConnection):
        // Offline mode or retry later
        enableOfflineMode()
        
    case .http(let status) where status.code == 401:
        // Authentication required
        presentLoginScreen()
        
    case .http(let status) where status.isServerError:
        // Server issues - suggest retry
        showRetryOption()
        
    case .timeout:
        // Timeout - suggest retry or check connection
        suggestRetryOrCheckConnection()
        
    default:
        // Generic error handling
        showGenericErrorMessage()
    }
    
    // Use recovery suggestions
    if !error.recoverySuggestions.isEmpty {
        showRecoverySuggestions(error.recoverySuggestions)
    }
}
```

## Type Aliases

### HTTPResult

Convenient Result type for HTTP operations:

```swift
/// Result type for HTTP operations
public typealias HTTPResult = Result<HTTPResponse, HTTPError>
```

**Usage:**

```swift
func performRequest() -> HTTPResult {
    do {
        let response = try await client.execute(request)
        return .success(response)
    } catch let error as HTTPError {
        return .failure(error)
    }
}

// Using the result
let result = performRequest()
switch result {
case .success(let response):
    print("Success: \(response.status)")
case .failure(let error):
    print("Error: \(error.userFriendlyDescription)")
}
```

## Thread Safety

All HTTP primitive types are `Sendable` and designed for safe concurrent access:

```swift
// Safe to pass between concurrent contexts
Task {
    let request = HTTPRequest(method: .get, url: url)
    let response = try await client.execute(request)
    
    await processResponse(response)  // Safe to pass to other contexts
}
```

## Best Practices

### Request Creation

- Use the request builder DSL for complex requests
- Set appropriate timeouts based on operation type
- Include necessary headers for your API
- Validate URLs before creating requests

### Response Processing

- Always check status codes before processing data
- Handle different content types appropriately
- Use structured error handling for different failure scenarios
- Consider caching successful responses

### Error Handling

- Catch and handle `HTTPError` specifically
- Use user-friendly error messages for UI
- Implement appropriate retry logic based on error category
- Log detailed error information for debugging

## See Also

- ``NetworkClient``
- ``RequestBuilder``
- ``HTTPClient``
- <doc:RequestBuilding>
- <doc:ADVANCED_USAGE>
- <doc:MIGRATION_GUIDE>