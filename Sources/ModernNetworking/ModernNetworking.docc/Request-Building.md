# Request Building

Build HTTP requests using the fluent, declarative API.

## Overview

ModernNetworking provides a powerful request builder that uses Swift's result builder pattern to create HTTP requests in a readable, declarative manner. The request builder eliminates boilerplate and provides type safety while maintaining flexibility.

## Basic Request Building

### Simple Requests

Create basic HTTP requests using method components:

```swift
// Simple GET request
let request = try RequestBuilder.build {
    GET("/api/users")
}

// POST request with JSON body
let request = try RequestBuilder.build {
    POST("/api/users")
    JSONBody(newUser)
}

// PUT request with authentication
let request = try RequestBuilder.build {
    PUT("/api/users/123")
    BearerAuth(token)
    JSONBody(updatedUser)
}
```

### Request Execution

Execute requests with a configured client:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
}

let response = try await client.execute {
    GET("/users")
    QueryParam("limit", "10")
}
```

## HTTP Methods

### Method Components

Available HTTP method components:

```swift
// Standard HTTP methods
GET("/path")          // GET request
POST("/path")         // POST request  
PUT("/path")          // PUT request
DELETE("/path")       // DELETE request

// Methods set both the HTTP method and path
let request = try RequestBuilder.build {
    POST("/api/users")
    // Additional components...
}
```

### Custom Methods

For non-standard HTTP methods, create the request manually:

```swift
let request = HTTPRequest(
    method: HTTPMethod("PATCH"),
    url: URL(string: "https://api.example.com/users/123")!
)
```

## URL and Path Building

### Base URL Resolution

Requests can use absolute or relative URLs:

```swift
// Absolute URL (ignores client base URL)
GET("https://external-api.com/data")

// Relative URL (uses client base URL)
GET("/api/users")

// Path segments are automatically combined
RequestBaseURL("https://api.example.com")
GET("/users/123/posts")
// Results in: https://api.example.com/users/123/posts
```

### Dynamic Path Building

Build paths dynamically:

```swift
let userId = "123"
let endpoint = "/users/\(userId)"

let request = try RequestBuilder.build {
    GET(endpoint)
}
```

## Headers

### Individual Headers

Add headers one at a time:

```swift
let request = try RequestBuilder.build {
    GET("/api/data")
    Header("Accept", "application/json")
    Header("User-Agent", "MyApp/1.0")
    Header("X-Custom-Header", "value")
}
```

### Common Header Components

Use semantic header components:

```swift
let request = try RequestBuilder.build {
    GET("/api/data")
    ContentType("application/json")
    AcceptHeader("application/json, text/plain")
    UserAgent("MyApp/2.0 (iOS)")
}
```

### Authentication Headers

Add authentication using dedicated components:

```swift
// Bearer token authentication
BearerAuth(token)
// Results in: Authorization: Bearer <token>

// Basic authentication
RequestBasicAuth(username: "user", password: "pass")
// Results in: Authorization: Basic <base64-encoded>

// API key authentication
APIKey(key: "api-key", headerName: "X-API-Key")
// Results in: X-API-Key: api-key
```

## Request Body

### JSON Body

Send JSON data with automatic encoding:

```swift
struct User: Codable {
    let name: String
    let email: String
}

let newUser = User(name: "John", email: "john@example.com")

let request = try RequestBuilder.build {
    POST("/api/users")
    JSONBody(newUser)
    ContentType("application/json")
}
```

### Data Body

Send raw data:

```swift
let imageData = UIImage(named: "profile")?.jpegData(compressionQuality: 0.8)

let request = try RequestBuilder.build {
    POST("/api/upload")
    DataBody(imageData)
    ContentType("image/jpeg")
}
```

### Form Body

Send form-encoded data:

```swift
let formData = [
    "username": "johndoe",
    "password": "secret123",
    "remember_me": "true"
]

let request = try RequestBuilder.build {
    POST("/api/login")
    FormBody(formData)
}
```

## Query Parameters

### Individual Query Parameters

Add query parameters one at a time:

```swift
let request = try RequestBuilder.build {
    GET("/api/search")
    QueryParam("q", "swift")
    QueryParam("limit", "10")
    QueryParam("offset", "0")
}
// Results in: /api/search?q=swift&limit=10&offset=0
```

### Multiple Query Parameters

Add multiple parameters at once:

```swift
let searchParams = [
    "q": "networking",
    "category": "ios",
    "sort": "date"
]

let request = try RequestBuilder.build {
    GET("/api/search")
    QueryParams(searchParams)
}
```

### Dynamic Query Building

Build queries conditionally:

```swift
let request = try RequestBuilder.build {
    GET("/api/users")
    
    if let searchTerm = searchTerm {
        QueryParam("search", searchTerm)
    }
    
    if includeInactive {
        QueryParam("include_inactive", "true")
    }
}
```

## Timeouts

### Request-Level Timeout

Set timeout for individual requests:

```swift
let request = try RequestBuilder.build {
    GET("/api/large-dataset")
    Timeout(60.0) // 60 seconds
}
```

### Global Timeout

Set default timeout at client level:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    DefaultTimeout(30.0)
}
```

## Conditional Components

### Conditional Inclusion

Include components conditionally:

```swift
let request = try RequestBuilder.build {
    GET("/api/data")
    
    if needsAuth {
        BearerAuth(authToken)
    }
    
    if isDebug {
        Header("X-Debug", "true")
    }
}
```

### Using Conditional Helper

Use the conditional helper function:

```swift
let request = try RequestBuilder.build {
    GET("/api/data")
    
    `if`(needsAuth) {
        BearerAuth(authToken)
    }
    
    `if`(isDebug, Header("X-Debug", "true"))
}
```

### Environment-Aware Components

Create components that adapt to environment:

```swift
let request = try RequestBuilder.build {
    GET("/api/data")
    
    EnvironmentAware { environment in
        switch environment {
        case .development:
            return Header("X-Debug", "true")
        case .production:
            return EmptyComponent()
        }
    }
}
```

## Advanced Patterns

### Switch-Based Components

Use switch statements for complex conditional logic:

```swift
enum APIVersion {
    case v1, v2, v3
}

let request = try RequestBuilder.build {
    GET("/api/data")
    
    SwitchComponent(apiVersion) { version in
        switch version {
        case .v1:
            return Header("Accept", "application/vnd.api.v1+json")
        case .v2:
            return Header("Accept", "application/vnd.api.v2+json")
        case .v3:
            return Header("Accept", "application/vnd.api.v3+json")
        }
    }
}
```

### Composite Components

Group related components:

```swift
struct AuthenticatedAPIRequest: RequestComponent {
    let token: String
    let apiVersion: String
    
    func apply(to request: inout RequestBuilder.PartialRequest) throws {
        var headers = request.headers
        headers["Authorization"] = "Bearer \(token)"
        headers["X-API-Version"] = apiVersion
        headers["Accept"] = "application/json"
        request.headers = headers
    }
}

let request = try RequestBuilder.build {
    GET("/api/users")
    AuthenticatedAPIRequest(token: authToken, apiVersion: "v2")
}
```

### Request Templates

Create reusable request templates:

```swift
func apiRequest(
    _ method: String,
    _ path: String,
    authenticated: Bool = true
) -> [any RequestComponent] {
    var components: [any RequestComponent] = []
    
    // Add method and path
    switch method.uppercased() {
    case "GET": components.append(GET(path))
    case "POST": components.append(POST(path))
    case "PUT": components.append(PUT(path))
    case "DELETE": components.append(DELETE(path))
    default: break
    }
    
    // Add common headers
    components.append(ContentType("application/json"))
    components.append(AcceptHeader("application/json"))
    
    // Add authentication if needed
    if authenticated, let token = authToken {
        components.append(BearerAuth(token))
    }
    
    return components
}

// Usage
let request = try RequestBuilder.build {
    apiRequest("GET", "/users")
    QueryParam("limit", "10")
}
```

## Request Operators

### Addition Operator

Combine requests with additional components:

```swift
let baseRequest = HTTPRequest(
    method: .get,
    url: URL(string: "https://api.example.com/users")!
)

// Add single component
let authenticatedRequest = try baseRequest + BearerAuth(token)

// Add multiple components
let fullRequest = try baseRequest + [
    BearerAuth(token),
    QueryParam("limit", "10"),
    Header("Accept", "application/json")
]
```

### Pipeline Operator

Use functional pipeline style:

```swift
let request = try HTTPRequest(
    method: .get,
    url: URL(string: "https://api.example.com/users")!
)
|> BearerAuth(token)
|> QueryParam("limit", "10")
|> ContentType("application/json")
```

## Cache Control

### Cache Headers

Add cache control headers:

```swift
let request = try RequestBuilder.build {
    GET("/api/static-data")
    CacheControl(.maxAge(3600))          // max-age=3600
    CacheControl(.noCache)               // no-cache
    CacheControl(.noStore)               // no-store
}
```

### Conditional Requests

Add conditional request headers:

```swift
let request = try RequestBuilder.build {
    GET("/api/data")
    IfNoneMatch(etag)                    // If-None-Match
    IfModifiedSince(lastModifiedDate)    // If-Modified-Since
}
```

## Error Handling

### Request Building Errors

Handle errors during request construction:

```swift
do {
    let request = try RequestBuilder.build {
        GET("") // Invalid empty path
        JSONBody(invalidData)
    }
} catch let error as HTTPError {
    print("Request building failed: \(error.localizedDescription)")
}
```

### Validation

Validate requests before execution:

```swift
struct RequestValidation: RequestComponent {
    func apply(to request: inout RequestBuilder.PartialRequest) throws {
        guard let url = request.url, !url.path.isEmpty else {
            throw HTTPError(category: .configuration("URL path cannot be empty"))
        }
        
        if request.method == .post || request.method == .put {
            guard request.body != nil else {
                throw HTTPError(category: .configuration("POST/PUT requests require a body"))
            }
        }
    }
}

let request = try RequestBuilder.build {
    POST("/api/users")
    RequestValidation() // Will throw if no body provided
    JSONBody(userData)
}
```

## Best Practices

### 1. Use Semantic Components

Prefer semantic components over raw headers:

```swift
// Good
ContentType("application/json")
BearerAuth(token)

// Less ideal
Header("Content-Type", "application/json")
Header("Authorization", "Bearer \(token)")
```

### 2. Group Related Components

Group related configuration:

```swift
// Good: Grouped authentication setup
let request = try RequestBuilder.build {
    POST("/api/secure-endpoint")
    
    // Authentication block
    BearerAuth(token)
    Header("X-API-Version", "v2")
    
    // Request body
    JSONBody(requestData)
    ContentType("application/json")
}
```

### 3. Use Conditional Logic Appropriately

Make conditional logic clear and readable:

```swift
let request = try RequestBuilder.build {
    GET("/api/data")
    
    // Clear conditional logic
    if let authToken = userSession.token {
        BearerAuth(authToken)
    }
    
    if configuration.includeMetadata {
        Header("X-Include-Metadata", "true")
    }
}
```

### 4. Create Reusable Components

Extract common patterns into reusable components:

```swift
struct StandardAPIHeaders: RequestComponent {
    func apply(to request: inout RequestBuilder.PartialRequest) throws {
        request.headers["Accept"] = "application/json"
        request.headers["User-Agent"] = "MyApp/\(Bundle.main.version)"
        request.headers["X-Client-Platform"] = "iOS"
    }
}
```

## Related Topics

- <doc:Core-Networking>: HTTP primitives and concepts
- <doc:Client-Configuration>: Client setup and configuration
- <doc:Response-Processing>: Handling responses
- <doc:Authentication>: Authentication patterns