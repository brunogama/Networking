# Request Building

Build HTTP requests declaratively using the RequestBuilder DSL and component system.

## Overview

The Networking framework provides a powerful, declarative way to build HTTP requests using result builders. This approach makes request construction readable, type-safe, and composable while supporting complex request patterns.

The request building system consists of:
- **RequestBuilder**: A result builder for declarative request construction
- **RequestComponent**: Protocol for request building components  
- **Predefined Components**: Common components for HTTP methods, headers, body content, and more
- **Conditional Logic**: Support for conditional request building

## Basic Request Building

### Simple Requests

Create requests using the clean DSL syntax:

```swift
// GET request
let request = HTTPRequest {
    GET("/api/users")
}

// POST request with JSON body
let request = HTTPRequest {
    POST("/api/users")
    Header("Content-Type", "application/json")
    JSONBody(newUser)
}

// PUT request with authentication
let request = HTTPRequest {
    PUT("/api/users/123")
    BearerAuth(token)
    JSONBody(updatedUser)
    Timeout(30.0)
}
```

### Executing Requests

Use requests directly with NetworkClient:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
}

let response = try await client.execute {
    GET("/users/123")
    Header("Accept", "application/json")
}
```

## HTTP Methods

### Standard HTTP Methods

All standard HTTP methods are supported:

```swift
// GET request
let getRequest = HTTPRequest {
    GET("/api/resource")
}

// POST request  
let postRequest = HTTPRequest {
    POST("/api/resource")
    JSONBody(data)
}

// PUT request
let putRequest = HTTPRequest {
    PUT("/api/resource/123")
    JSONBody(updatedData)
}

// DELETE request
let deleteRequest = HTTPRequest {
    DELETE("/api/resource/123")
}

// PATCH request
let patchRequest = HTTPRequest {
    PATCH("/api/resource/123")
    JSONBody(partialUpdate)
}

// HEAD request
let headRequest = HTTPRequest {
    HEAD("/api/resource")
}
```

### Custom HTTP Methods

Support for non-standard HTTP methods:

```swift
// Using custom method
let customRequest = HTTPRequest {
    Method("CUSTOM")
    Path("/api/custom-endpoint")
}
```

## Request Components

### Headers

Add headers to your requests:

```swift
let request = HTTPRequest {
    GET("/api/data")
    
    // Individual headers
    Header("Accept", "application/json")
    Header("X-Client-Version", "1.0")
    
    // Content-Type shortcuts
    ContentType(.json)        // application/json
    ContentType(.xml)         // application/xml
    ContentType(.formURLEncoded) // application/x-www-form-urlencoded
    
    // Accept shortcuts
    AcceptHeader(.json)       // Accept: application/json
    AcceptHeader(.xml)        // Accept: application/xml
    
    // User-Agent
    UserAgent("MyApp/1.0")
}
```

### Authentication

Add authentication to individual requests:

```swift
// Bearer token
let request = HTTPRequest {
    GET("/api/protected")
    BearerAuth("your-token-here")
}

// Basic authentication
let request = HTTPRequest {
    GET("/api/protected")
    RequestBasicAuth(username: "user", password: "pass")
}

// API Key
let request = HTTPRequest {
    GET("/api/protected")
    APIKey("X-API-Key", "your-api-key")
}

// Custom authentication
let request = HTTPRequest {
    GET("/api/protected")
    Header("Authorization", "Custom \(customToken)")
}
```

### Query Parameters

Add query parameters to requests:

```swift
let request = HTTPRequest {
    GET("/api/search")
    
    // Individual parameters
    QueryParam("q", "swift networking")
    QueryParam("limit", "10")
    QueryParam("offset", "0")
    
    // Multiple parameters at once
    QueryParams([
        "sort": "name",
        "order": "asc",
        "filter": "active"
    ])
}
```

### Request Body

Add different types of request bodies:

```swift
// JSON body (automatically sets Content-Type)
struct User: Codable {
    let name: String
    let email: String
}

let request = HTTPRequest {
    POST("/api/users")
    JSONBody(User(name: "John", email: "john@example.com"))
}

// Raw Data body
let request = HTTPRequest {
    POST("/api/data")
    DataBody(myData)
    ContentType(.octetStream)
}

// Form body (automatically sets Content-Type)
let request = HTTPRequest {
    POST("/api/form")
    FormBody([
        "name": "John Doe",
        "email": "john@example.com",
        "subscribe": "true"
    ])
}

// String body
let request = HTTPRequest {
    POST("/api/text")
    StringBody("Plain text content")
    ContentType(.plainText)
}
```

### Request Configuration

Configure request-specific settings:

```swift
let request = HTTPRequest {
    GET("/api/slow-endpoint")
    
    // Custom timeout for this request
    RequestTimeout(60.0)
    
    // Override base URL for this request  
    RequestBaseURL("https://different-api.example.com")
    
    // Cache control
    CachePolicy(.reloadIgnoringLocalCacheData)
}
```

## Conditional Request Building

### Conditional Components

Build requests dynamically based on runtime conditions:

```swift
let includeAuth = user.isLoggedIn
let includeDetails = user.isPremium

let request = HTTPRequest {
    GET("/api/profile")
    
    // Conditional authentication
    if(includeAuth) {
        BearerAuth(user.token)
    }
    
    // Conditional query parameters
    if(includeDetails) {
        QueryParam("include", "premium-details")
    }
}
```

### Conditional Helper

Use the conditional helper for cleaner code:

```swift
let request = HTTPRequest {
    GET("/api/data")
    
    ConditionalComponent(user.isLoggedIn) {
        BearerAuth(user.token)
        Header("X-User-ID", user.id)
    }
    
    ConditionalComponent(!searchTerm.isEmpty) {
        QueryParam("search", searchTerm)
    }
}
```

## Advanced Patterns

### Request Composition

Build reusable request components:

```swift
// Common authentication component
@RequestBuilder
func commonAuth(for user: User) -> [RequestComponent] {
    if user.isLoggedIn {
        BearerAuth(user.token)
        Header("X-User-ID", user.id)
    }
}

// Common headers component
@RequestBuilder  
func commonHeaders() -> [RequestComponent] {
    Header("Accept", "application/json")
    Header("X-Client-Version", "1.0")
    UserAgent("MyApp/1.0")
}

// Use in requests
let request = HTTPRequest {
    GET("/api/profile")
    commonAuth(for: currentUser)
    commonHeaders()
}
```

### Request Templates

Create request templates for common patterns:

```swift
// API request template
func apiRequest<T: Codable>(
    method: HTTPMethod,
    path: String,
    body: T? = nil,
    authenticated: Bool = true
) -> HTTPRequest {
    HTTPRequest {
        Method(method.rawValue)
        Path(path)
        
        commonHeaders()
        
        if authenticated {
            commonAuth(for: currentUser)
        }
        
        if let body = body {
            JSONBody(body)
        }
    }
}

// Use template
let request = apiRequest(
    method: .post,
    path: "/api/users",
    body: newUser,
    authenticated: true
)
```

### Request Validation

Add validation to request components:

```swift
struct ValidatedPath: RequestComponent {
    let path: String
    
    init(_ path: String) throws {
        guard path.starts(with: "/") else {
            throw RequestError.invalidPath("Path must start with /")
        }
        guard !path.contains("..") else {
            throw RequestError.invalidPath("Path cannot contain ..")
        }
        self.path = path
    }
    
    func apply(to request: inout HTTPRequest) throws {
        // Apply validated path
    }
}

// Use validated component
let request = HTTPRequest {
    GET(try ValidatedPath("/api/safe-path"))
}
```

## Component Reference

### HTTP Method Components

| Component | Description | Example |
|-----------|-------------|---------|
| `GET(path)` | HTTP GET request | `GET("/users")` |
| `POST(path)` | HTTP POST request | `POST("/users")` |
| `PUT(path)` | HTTP PUT request | `PUT("/users/123")` |
| `DELETE(path)` | HTTP DELETE request | `DELETE("/users/123")` |
| `PATCH(path)` | HTTP PATCH request | `PATCH("/users/123")` |
| `HEAD(path)` | HTTP HEAD request | `HEAD("/users")` |

### Header Components

| Component | Description | Example |
|-----------|-------------|---------|
| `Header(name, value)` | Generic header | `Header("Accept", "application/json")` |
| `ContentType(type)` | Content-Type header | `ContentType(.json)` |
| `AcceptHeader(type)` | Accept header | `AcceptHeader(.json)` |
| `UserAgent(string)` | User-Agent header | `UserAgent("MyApp/1.0")` |

### Authentication Components

| Component | Description | Example |
|-----------|-------------|---------|
| `BearerAuth(token)` | Bearer token authentication | `BearerAuth("abc123")` |
| `RequestBasicAuth(user, pass)` | Basic authentication | `RequestBasicAuth(username: "user", password: "pass")` |
| `APIKey(header, key)` | API key authentication | `APIKey("X-API-Key", "secret")` |

### Body Components

| Component | Description | Example |
|-----------|-------------|---------|
| `JSONBody(object)` | JSON request body | `JSONBody(user)` |
| `DataBody(data)` | Raw data body | `DataBody(imageData)` |
| `FormBody(dict)` | Form-encoded body | `FormBody(["key": "value"])` |
| `StringBody(string)` | String body | `StringBody("text content")` |

### Configuration Components

| Component | Description | Example |
|-----------|-------------|---------|
| `RequestTimeout(seconds)` | Request timeout | `RequestTimeout(30.0)` |
| `RequestBaseURL(url)` | Override base URL | `RequestBaseURL("https://api.example.com")` |
| `QueryParam(name, value)` | Query parameter | `QueryParam("limit", "10")` |
| `QueryParams(dict)` | Multiple query parameters | `QueryParams(["sort": "name"])` |

## Best Practices

### Request Organization

- Group related components together
- Use descriptive parameter names
- Keep requests readable and maintainable

### Component Reuse

- Create reusable component functions for common patterns
- Extract authentication and header logic into shared components
- Use conditional components for dynamic request building

### Error Handling

- Validate input parameters in custom components
- Handle encoding errors gracefully
- Provide meaningful error messages

### Performance

- Avoid creating unnecessary intermediate objects
- Cache reusable components when appropriate
- Use efficient data serialization for request bodies

## See Also

- ``RequestBuilder``
- ``RequestComponent``
- ``HTTPRequest``
- ``NetworkClient``
- <doc:HTTPMethods>
- <doc:RequestComponents>
- <doc:ConditionalRequests>