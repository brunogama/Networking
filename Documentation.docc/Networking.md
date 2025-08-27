# ``Networking``

A modern, Swift 6 compliant networking framework built with async/await and structured concurrency.

## Overview

Networking is a comprehensive HTTP client framework designed for modern Swift applications. It provides a declarative, type-safe API for network operations with powerful middleware support, advanced caching, security features, and comprehensive error handling.

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

### Quick Start

Create a simple HTTP client and make requests:

```swift
import Networking

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

### Essentials

- <doc:GettingStarted>

### Core Networking

- <doc:HTTPPrimitives>
- <doc:NetworkClient>
- <doc:RequestBuilding>

### Configuration & Client Setup

- <doc:ClientConfiguration>

### Request Building

- <doc:HTTPMethods>
- <doc:RequestComponents>
- <doc:ConditionalRequests>

### Middleware System

- <doc:MiddlewareOverview>

## Framework Architecture

### Core Components

1. **HTTP Layer**: Fundamental types (`HTTPRequest`, `HTTPResponse`, `HTTPError`)
2. **Client Layer**: `NetworkClient` with middleware pipeline
3. **Configuration Layer**: Declarative DSL components using result builders
4. **Middleware Layer**: Pluggable request/response processing
5. **Generation Layer**: Swift macro-based API client generation
6. **Utility Layer**: Caching, security, metrics, and progress tracking

### Design Principles

- **Type Safety**: Extensive use of Swift's type system for compile-time safety
- **Concurrency**: Full Swift 6 compliance with structured concurrency
- **Composability**: Middleware and configuration components can be mixed and matched
- **Extensibility**: Protocol-based design allows custom implementations
- **Performance**: Minimal overhead with efficient caching and connection reuse

## Requirements

- iOS 16.0+ / macOS 13.0+ / tvOS 16.0+ / watchOS 9.0+
- Swift 6.0+
- Xcode 16.0+

## See Also

- ``HTTPClient``
- ``NetworkClient`` 
- ``HTTPRequest``
- ``HTTPResponse``
- ``RequestBuilder``