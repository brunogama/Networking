# Request Components

Modular building blocks for constructing HTTP requests with the RequestComponent protocol.

## Overview

Request components are the foundation of the declarative request building system. Each component represents a specific aspect of an HTTP request and can be combined to create complex requests in a readable, type-safe manner.

The RequestComponent system provides:
- **Modular Architecture**: Each component handles a specific request aspect
- **Composability**: Components can be mixed and matched freely
- **Type Safety**: Compile-time validation of component usage
- **Extensibility**: Create custom components for specialized needs

## RequestComponent Protocol

### Core Protocol

All request components conform to the ``RequestComponent`` protocol:

```swift
/// Protocol for components that modify HTTP requests
public protocol RequestComponent {
    /// Apply this component's modifications to the request
    /// - Parameter request: The request to modify
    /// - Throws: Any errors that occur during application
    func apply(to request: inout HTTPRequest) throws
}
```

### Component Lifecycle

Components are applied in the order they appear in the request builder:

```swift
let request = HTTPRequest {
    // 1. Method and path
    POST("/api/users")
    
    // 2. Headers (applied in order)
    Header("Accept", "application/json")
    ContentType(.json)
    
    // 3. Authentication
    BearerAuth(token)
    
    // 4. Body content
    JSONBody(user)
    
    // 5. Request configuration
    Timeout(30.0)
}
```

## Built-in Components

### HTTP Method Components

Components that set the HTTP method and path:

```swift
// Standard HTTP methods
GET("/api/users")
POST("/api/users")
PUT("/api/users/123")
PATCH("/api/users/123")
DELETE("/api/users/123")
HEAD("/api/users")
OPTIONS("/api/users")

// Custom method
Method("PROPFIND")
Path("/webdav/collection")
```

### Header Components

Components for managing request headers:

```swift
// Generic header
Header("Accept", "application/json")
Header("X-Client-Version", "1.0")

// Specialized header components
ContentType(.json)              // Content-Type: application/json
AcceptHeader(.xml)              // Accept: application/xml
UserAgent("MyApp/1.0")         // User-Agent: MyApp/1.0
CacheControl("no-cache")       // Cache-Control: no-cache
```

**Content Type Shortcuts:**

```swift
ContentType(.json)             // application/json
ContentType(.xml)              // application/xml
ContentType(.formURLEncoded)   // application/x-www-form-urlencoded
ContentType(.plainText)        // text/plain
ContentType(.html)             // text/html
ContentType(.octetStream)      // application/octet-stream
```

### Authentication Components

Components for various authentication methods:

```swift
// Bearer token authentication
BearerAuth("your-token-here")

// Basic authentication
RequestBasicAuth(username: "user", password: "pass")

// API key authentication
APIKey("X-API-Key", "your-api-key")
APIKey("Authorization", "Bearer \(token)")

// Custom authentication
CustomAuth { request in
    var modifiedRequest = request
    modifiedRequest.headers["X-Custom-Auth"] = computeSignature(request)
    return modifiedRequest
}
```

### Body Components

Components for request body content:

```swift
// JSON body (automatically sets Content-Type)
struct User: Codable {
    let name: String
    let email: String
}
JSONBody(User(name: "John", email: "john@example.com"))

// Raw data body
DataBody(imageData)

// Form-encoded body (automatically sets Content-Type)  
FormBody([
    "username": "john_doe",
    "password": "secret123",
    "remember_me": "true"
])

// String body
StringBody("Plain text content")

// Empty body (explicit)
EmptyBody()
```

### Query Parameter Components

Components for URL query parameters:

```swift
// Individual parameters
QueryParam("page", "1")
QueryParam("limit", "25")
QueryParam("sort", "name")

// Multiple parameters at once
QueryParams([
    "filter": "active",
    "include": "profile",
    "expand": "permissions"
])

// Array parameters
QueryParamArray("tags", ["swift", "networking", "ios"])
// Results in: ?tags=swift&tags=networking&tags=ios

// URL-encoded parameters
QueryParam("search", "hello world") // Automatically URL-encoded
```

### Configuration Components

Components for request-level configuration:

```swift
// Request timeout
RequestTimeout(60.0)          // 60 seconds
RequestTimeout(.minutes(5))   // 5 minutes

// Base URL override
RequestBaseURL("https://staging-api.example.com")

// Cache policy
CachePolicy(.reloadIgnoringLocalCacheData)
CachePolicy(.returnCacheDataDontLoad)

// Network service type
NetworkServiceType(.video)    // Optimize for video streaming
NetworkServiceType(.background) // Background processing
```

## Creating Custom Components

### Simple Custom Components

Create components for common patterns:

```swift
// API version header component
struct APIVersion: RequestComponent {
    let version: String
    
    func apply(to request: inout HTTPRequest) throws {
        request.headers["X-API-Version"] = version
    }
}

// Usage
let request = HTTPRequest {
    GET("/api/users")
    APIVersion("v2")
}
```

### Parameterized Components

Components with configuration options:

```swift
// Retry policy component
struct RetryPolicy: RequestComponent {
    let maxAttempts: Int
    let backoffMultiplier: Double
    
    func apply(to request: inout HTTPRequest) throws {
        request.headers["X-Max-Retries"] = "\(maxAttempts)"
        request.headers["X-Backoff-Multiplier"] = "\(backoffMultiplier)"
    }
}

// Usage
let request = HTTPRequest {
    GET("/api/flaky-endpoint")
    RetryPolicy(maxAttempts: 3, backoffMultiplier: 2.0)
}
```

### Conditional Components

Components that apply based on conditions:

```swift
// Conditional authentication
struct ConditionalAuth: RequestComponent {
    let token: String?
    
    func apply(to request: inout HTTPRequest) throws {
        if let token = token {
            request.headers["Authorization"] = "Bearer \(token)"
        }
    }
}

// Debug headers (only in debug builds)
struct DebugHeaders: RequestComponent {
    let buildInfo: String
    
    func apply(to request: inout HTTPRequest) throws {
        #if DEBUG
        request.headers["X-Build-Info"] = buildInfo
        request.headers["X-Debug-Mode"] = "true"
        #endif
    }
}
```

### Validation Components

Components that validate request properties:

```swift
// Path validation component
struct ValidatedPath: RequestComponent {
    let path: String
    
    init(_ path: String) throws {
        guard path.hasPrefix("/") else {
            throw RequestError.invalidPath("Path must start with /")
        }
        guard !path.contains("..") else {
            throw RequestError.invalidPath("Path cannot contain '..'")
        }
        self.path = path
    }
    
    func apply(to request: inout HTTPRequest) throws {
        // Apply validated path
        if var components = URLComponents(url: request.url, resolvingAgainstBaseURL: false) {
            components.path = path
            if let newURL = components.url {
                request = HTTPRequest(
                    method: request.method,
                    url: newURL,
                    headers: request.headers,
                    body: request.body,
                    timeout: request.timeout
                )
            }
        }
    }
}
```

### Complex Custom Components

Components that perform multiple operations:

```swift
// Complete request signing component
struct RequestSigner: RequestComponent {
    let apiKey: String
    let secretKey: String
    
    func apply(to request: inout HTTPRequest) throws {
        let timestamp = String(Int(Date().timeIntervalSince1970))
        let bodyHash = SHA256.hash(data: request.body ?? Data())
        
        // Create signature string
        let signatureString = [
            request.method.rawValue,
            request.url.path,
            timestamp,
            bodyHash.hexString
        ].joined(separator: "\n")
        
        // Generate HMAC signature
        let signature = HMAC<SHA256>.authenticationCode(
            for: signatureString.data(using: .utf8)!,
            using: SymmetricKey(data: secretKey.data(using: .utf8)!)
        )
        
        // Apply headers
        request.headers["X-API-Key"] = apiKey
        request.headers["X-Timestamp"] = timestamp
        request.headers["X-Signature"] = signature.hexString
    }
}
```

## Component Composition

### Combining Components

Create reusable component groups:

```swift
// Common API request components
@RequestBuilder
func commonAPIComponents(token: String) -> [RequestComponent] {
    Header("Accept", "application/json")
    Header("User-Agent", "MyApp/1.0")
    BearerAuth(token)
    APIVersion("v2")
    RequestTimeout(30.0)
}

// Usage
let request = HTTPRequest {
    GET("/api/users")
    commonAPIComponents(token: userToken)
}
```

### Component Factory Functions

Create factory functions for complex components:

```swift
// Pagination components factory
func paginationComponents(page: Int, limit: Int = 25) -> [RequestComponent] {
    return [
        QueryParam("page", "\(page)"),
        QueryParam("limit", "\(limit)"),
        QueryParam("offset", "\((page - 1) * limit)")
    ]
}

// Sorting components factory
func sortingComponents(field: String, order: String = "asc") -> [RequestComponent] {
    return [
        QueryParam("sort", field),
        QueryParam("order", order)
    ]
}

// Usage
let request = HTTPRequest {
    GET("/api/users")
    paginationComponents(page: 2, limit: 50)
    sortingComponents(field: "name", order: "desc")
}
```

## Component Patterns

### Builder Pattern Components

Components that configure themselves:

```swift
// Configurable cache component
struct CacheConfiguration: RequestComponent {
    private var policy: URLRequest.CachePolicy = .useProtocolCachePolicy
    private var maxAge: TimeInterval = 300
    
    func policy(_ policy: URLRequest.CachePolicy) -> Self {
        var copy = self
        copy.policy = policy
        return copy
    }
    
    func maxAge(_ seconds: TimeInterval) -> Self {
        var copy = self
        copy.maxAge = seconds
        return copy
    }
    
    func apply(to request: inout HTTPRequest) throws {
        request.cachePolicy = policy
        request.headers["Cache-Control"] = "max-age=\(Int(maxAge))"
    }
}

// Usage
let request = HTTPRequest {
    GET("/api/data")
    CacheConfiguration()
        .policy(.reloadIgnoringLocalCacheData)
        .maxAge(600)
}
```

### Conditional Application

Apply components based on runtime conditions:

```swift
let request = HTTPRequest {
    GET("/api/data")
    
    // Apply authentication if user is logged in
    if user.isLoggedIn {
        BearerAuth(user.token)
    }
    
    // Apply debug headers in development
    if Environment.isDevelopment {
        Header("X-Debug", "true")
        Header("X-Environment", "development")
    }
    
    // Apply premium features for premium users
    if user.isPremium {
        QueryParam("include_premium", "true")
    }
}
```

## Component Error Handling

### Component-Level Errors

Handle errors at the component level:

```swift
struct SafeHeader: RequestComponent {
    let name: String
    let value: String
    
    func apply(to request: inout HTTPRequest) throws {
        guard !name.isEmpty else {
            throw RequestError.invalidHeader("Header name cannot be empty")
        }
        
        guard name.allSatisfy({ $0.isASCII && !$0.isWhitespace }) else {
            throw RequestError.invalidHeader("Header name contains invalid characters")
        }
        
        request.headers[name] = value
    }
}
```

### Component Validation Chain

Validate components before application:

```swift
extension RequestComponent {
    func validated() -> ValidatedComponent<Self> {
        return ValidatedComponent(self)
    }
}

struct ValidatedComponent<T: RequestComponent>: RequestComponent {
    let component: T
    
    init(_ component: T) {
        self.component = component
    }
    
    func apply(to request: inout HTTPRequest) throws {
        // Perform pre-validation
        try validateComponent(component, for: request)
        
        // Apply the component
        try component.apply(to: &request)
        
        // Perform post-validation
        try validateRequest(request)
    }
}
```

## Performance Considerations

### Component Efficiency

- Components are applied in order during request building
- Avoid expensive operations in component `apply` methods
- Cache computed values when possible
- Use lazy evaluation for optional components

### Memory Management

```swift
// Efficient component design
struct EfficientComponent: RequestComponent {
    // Use value types when possible
    let value: String
    
    // Avoid retaining unnecessary references
    func apply(to request: inout HTTPRequest) throws {
        // Direct manipulation is more efficient than creating new objects
        request.headers["X-Value"] = value
    }
}
```

## See Also

- ``RequestComponent``
- ``RequestBuilder``
- ``HTTPRequest``
- <doc:RequestBuilding>
- <doc:HTTPMethods>
- <doc:ConditionalRequests>