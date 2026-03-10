# Getting Started

Learn how to integrate and use Networking in your Swift applications.

## Overview

Networking provides a modern, declarative approach to HTTP networking in Swift. This guide will walk you through the basics of setting up and using the framework.

`Networking` remains the recommended default import. Use direct module imports only when you want to
keep a target scoped to a smaller dependency surface.

## Installation

### Swift Package Manager

Add Networking to your project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/yourorg/Networking", from: "1.0.0")
]
```

Then import the framework:

```swift
import Networking
```

For package-level adoption, import the smallest module set that matches the behavior you need:

```swift
import NetworkingRuntime
import NetworkingDSL
import NetworkingRuntimeDSL
```

## Basic Concepts

### NetworkClient

The `NetworkClient` is the main entry point for making HTTP requests. It uses a declarative configuration system:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    DefaultTimeout(30.0)
    EnableLogging()
    DefaultHeader("Content-Type", "application/json")
}
```

### Request Building

Use the fluent request builder API to construct HTTP requests:

```swift
let response = try await client.execute {
    GET("/users")
    QueryParam("limit", "10")
    BearerAuth(authToken)
}
```

### Response Handling

Handle responses with built-in decoding support:

```swift
// Decode JSON directly
let users: [User] = try response.decode([User].self)

// Or work with raw data
let data = response.body
let statusCode = response.status.rawValue
```

## Common Patterns

### Authentication

Configure authentication at the client level:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    Authentication {
        BearerToken(tokenProvider)
        AuthRefreshStrategy(.automatic)
    }
}
```

Or per-request:

```swift
let response = try await client.execute {
    POST("/api/data")
    BearerAuth(token)
    JSONBody(requestData)
}
```

### Error Handling

Networking provides comprehensive error handling:

```swift
do {
    let response = try await client.execute {
        GET("/api/data")
    }
    let data = try response.decode(MyData.self)
} catch let httpError as HTTPError {
    switch httpError.category {
    case .http(let status):
        // Handle specific HTTP status codes
        if status == .unauthorized {
            // Handle authentication error
        }
    case .network(let networkError):
        // Handle network-level errors
        switch networkError {
        case .noConnection:
            // Handle offline state
        case .serverUnreachable:
            // Handle server issues
        }
    case .decoding(let message):
        // Handle JSON decoding errors
        print("Failed to decode response: \(message)")
    }
}
```

### Runtime Extensibility

Use middleware for new runtime behavior:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    AddMiddleware(AuthenticationMiddleware(tokenProvider: tokenProvider))
    AddMiddleware(RetryMiddleware())
}
```

`NetworkingInterceptorsCompat` remains available for compatibility, but new extension work should
prefer middleware.

### Retry Logic

Enable automatic retry for transient failures:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    Retry {
        MaxAttempts(3)
        BackoffStrategy(.exponential)
        RetryWhen { error in
            // Custom retry conditions
            error.isRetryable
        }
    }
}
```

### Caching

Configure response caching:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    Caching {
        Policy(.standard)
        Storage(.memory(size: .MB(50)))
        Duration(.ttl(300)) // 5 minutes
    }
}
```

## Generated API Clients

Use macros to generate type-safe API clients:

```swift
@API(baseURL: "https://jsonplaceholder.typicode.com")
protocol JSONPlaceholderAPI {
    @GET("/posts")
    func getPosts() async throws -> [Post]
    
    @GET("/posts/{id}")
    func getPost(@Path id: Int) async throws -> Post
    
    @POST("/posts")
    func createPost(@Body post: CreatePostRequest) async throws -> Post
    
    @PUT("/posts/{id}")
    func updatePost(@Path id: Int, @Body post: UpdatePostRequest) async throws -> Post
    
    @DELETE("/posts/{id}")
    func deletePost(@Path id: Int) async throws
}

// Use the generated implementation
let api = JSONPlaceholderAPIImplementation()
let posts = try await api.getPosts()
```

## Advanced Configuration

### Custom Session Configuration

Configure URLSession behavior:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    Session {
        SessionTimeout(60.0)
        AllowsCellular(true)
        WaitsForConnectivity(true)
        MaxConnectionsPerHost(6)
    }
}
```

### Security Configuration

Enable SSL pinning and security headers:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    EnableSecurity {
        SSLPinning(.certificates(certificates))
        SecurityHeaders(.strict)
    }
}
```

### Progress Tracking

Monitor upload and download progress:

```swift
let response = try await client.execute {
    POST("/upload")
    DataBody(largeData)
    ProgressTracking { progress in
        DispatchQueue.main.async {
            progressView.progress = Float(progress.fractionCompleted)
        }
    }
}
```

## Next Steps

- Explore the <doc:Middleware-Guide> to learn about custom middleware
- See <doc:Module-Migration> for the split package map and direct-import guidance
- Learn about <doc:Security-Features> for production applications
- Check out <doc:Testing-Guide> for testing strategies
- See <doc:API-Reference> for complete API documentation

## Sample Projects

The framework includes sample projects demonstrating various usage patterns:

- **BasicUsage**: Simple GET/POST requests with error handling
- **AuthenticatedAPI**: OAuth2 flow with token refresh
- **FileUpload**: Large file uploads with progress tracking
- **CachedAPI**: API client with intelligent caching
- **GeneratedClient**: Macro-based API client generation
