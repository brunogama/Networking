# ``ModernNetworking``

A modern, Swift 6 compliant networking framework built with async/await and structured concurrency.

## Overview

ModernNetworking is a comprehensive HTTP client framework designed for modern Swift applications. It provides a declarative, type-safe API for network operations with powerful middleware support, advanced caching, security features, and comprehensive error handling.

### Key Features

- **Swift 6 Compliant**: Built with structured concurrency and modern Swift patterns
- **Declarative DSL**: Fluent, readable API for constructing HTTP requests and client configurations
- **Macro-Based Code Generation**: Automatic API client generation with compile-time validation
- **Comprehensive Middleware**: Request/response processing, authentication, retry logic, caching, and more
- **Security-First**: SSL pinning, certificate validation, and security headers
- **Observability**: Built-in metrics, logging, and monitoring capabilities
- **Progress Tracking**: Real-time upload/download progress monitoring
- **Advanced Caching**: Multi-level caching with intelligent invalidation strategies
- **Error Recovery**: Actionable error information with automatic recovery strategies

## Getting Started

### Basic Usage

Create a simple HTTP client and make requests:

```swift
import ModernNetworking

// Create a client with fluent configuration
let client = NetworkClient {
    BaseURL("https://api.example.com")
    EnableLogging()
    EnableRetry()
    DefaultHeader("User-Agent", "MyApp/1.0")
}

// Make requests using the request builder
let response = try await client.execute {
    GET("/users/123")
    BearerAuth(token)
    Timeout(15.0)
}

// Decode response
let user: User = try response.decode(User.self)
```

### Generated API Clients

Use macros to generate type-safe API clients:

```swift
@API(baseURL: "https://api.example.com")
protocol UserAPI {
    @GET("/users/{id}")
    func getUser(@Path id: String) async throws -> User
    
    @POST("/users")
    func createUser(@Body user: User) async throws -> User
    
    @PUT("/users/{id}")
    @Cacheable(ttl: 300)
    func updateUser(@Path id: String, @Body user: User) async throws -> User
}

let userAPI = UserAPIImplementation()
let user = try await userAPI.getUser(id: "123")
```

## Topics

### Core Components

- <doc:Core-Networking>
- <doc:Request-Building>
- <doc:Response-Processing>
- <doc:Error-Handling>

### Configuration and Middleware

- <doc:Client-Configuration>
- <doc:Middleware-System>
- <doc:Authentication>
- <doc:Caching-System>

### Advanced Features

- <doc:Security-Features>
- <doc:Progress-Tracking>
- <doc:Metrics-and-Observability>
- <doc:Macro-Generated-APIs>

### Guides

- <doc:Getting-Started>
- <doc:Configuration-Guide>
- <doc:Middleware-Guide>
- <doc:Security-Guide>
- <doc:Testing-Guide>

## Requirements

- iOS 13.0+ / macOS 10.15+ / tvOS 13.0+ / watchOS 6.0+
- Swift 5.9+
- Xcode 15.0+

## Architecture

ModernNetworking follows a layered architecture with clear separation of concerns:

1. **Core Layer**: HTTP primitives (HTTPRequest, HTTPResponse, HTTPError)
2. **Client Layer**: NetworkClient implementation with middleware pipeline
3. **Configuration Layer**: Declarative client and request configuration
4. **Middleware Layer**: Pluggable request/response processing
5. **Generation Layer**: Macro-based API client generation
6. **Utility Layer**: Caching, security, metrics, and progress tracking

## Thread Safety

All public APIs in ModernNetworking are designed to be thread-safe and fully compatible with Swift's structured concurrency model. The framework uses `Sendable` protocols and `actor`-based isolation where appropriate to ensure safe concurrent access.