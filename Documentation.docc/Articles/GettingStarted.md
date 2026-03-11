# Getting Started

Learn how to integrate and use the Networking framework in your Swift applications.

## Overview

The Networking framework provides a modern, Swift 6 compliant HTTP client with a declarative API, middleware support, and advanced features like SSL pinning, caching, and progress tracking.

## Installation

### Swift Package Manager

Add the Networking framework to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/brunogama/Networking.git", from: "1.0.0")
]
```

Or add it through Xcode:
1. File → Add Package Dependencies
2. Enter `https://github.com/brunogama/Networking.git`
3. Select version and add to your target

## Basic Setup

### Creating Your First Client

The simplest way to create a networking client:

```swift
import Networking

let client = NetworkClient {
    BaseURL("https://api.example.com")
    DefaultTimeout(30.0)
    DefaultHeader("User-Agent", "MyApp/1.0")
}
```

### Making Your First Request

Execute a simple GET request:

```swift
let response = try await client.execute {
    GET("/users/123")
    Header("Accept", "application/json")
}

print("Status: \(response.status)")
print("Data: \(String(data: response.body ?? Data(), encoding: .utf8) ?? "No data")")
```

### Working with JSON

Decode JSON responses directly:

```swift
struct User: Codable {
    let id: Int
    let name: String
    let email: String
}

let response = try await client.execute {
    GET("/users/123")
    Header("Accept", "application/json")
}

let user: User = try response.decode(User.self)
print("User: \(user.name)")
```

## Key Concepts

### Declarative Configuration

The framework uses result builders to provide a clean, readable syntax:

```swift
let client = NetworkClient {
    // Base configuration
    BaseURL("https://api.example.com")
    DefaultTimeout(30.0)
    
    // Authentication
    BearerToken("your-token-here")
    
    // Headers
    DefaultHeader("User-Agent", "MyApp/1.0")
    DefaultHeader("Accept", "application/json")
    
    // Enable middleware
    EnableRetry()
    EnableLogging()
    EnableCaching()
}
```

### Request Building

Build requests using the same declarative syntax:

```swift
let request = HTTPRequest {
    POST("/api/users")
    Header("Content-Type", "application/json")
    JSONBody(newUser)
    Timeout(15.0)
}

let response = try await client.execute(request)
```

### Async/Await Support

All networking operations are async and built with structured concurrency:

```swift
// Sequential requests
let user = try await client.execute { GET("/user/123") }
let posts = try await client.execute { GET("/user/123/posts") }

// Concurrent requests
async let userTask = client.execute { GET("/user/123") }
async let postsTask = client.execute { GET("/user/123/posts") }

let (user, posts) = try await (userTask, postsTask)
```

## Next Steps

Now that you have the basics, explore more advanced features:

- <doc:ClientConfiguration>: Learn about comprehensive client configuration options
- <doc:MiddlewareOverview>: Understand the powerful middleware system
- <doc:ADVANCED_USAGE>: Advanced patterns and API client generation with macros
- <doc:SWIFT_6_FEATURES>: Modern Swift 6 concurrency patterns
- <doc:MIGRATION_GUIDE>: Migrating from URLSession or other frameworks

## Common Patterns

### Error Handling

```swift
do {
    let response = try await client.execute {
        GET("/api/data")
    }
    // Handle success
} catch let error as HTTPError {
    switch error.category {
    case .network(.noConnection):
        // Handle network issues
        print("No internet connection")
    case .http(.unauthorized):
        // Handle auth issues
        print("Please log in again")
    default:
        // Handle other errors
        print("Request failed: \(error.userFriendlyDescription)")
    }
}
```

### Request Retry

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    EnableRetry {
        MaxAttempts(3)
        BackoffStrategy(.exponential(multiplier: 2.0))
    }
}
```

### Response Caching

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    EnableCaching {
        Policy(.standard)
        Storage(.memory(maxSize: .megabytes(50)))
        Duration(.minutes(15))
    }
}
```

## See Also

- ``NetworkClient``
- ``HTTPRequest``
- ``HTTPResponse``
- <doc:GETTING_STARTED>
- <doc:TESTING_GUIDE>