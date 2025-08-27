# Networking

A Swift 6 networking framework designed for modern iOS, macOS, tvOS, and watchOS applications. Built with async/await, structured concurrency, and comprehensive security features.

## Features

### Core Networking
- Swift 6 compliant with full async/await URLSession integration
- Fluent DSL for declarative request/response building
- Result builder patterns for readable configuration
- Comprehensive middleware architecture
- File transfer operations with progress tracking
- Circuit breaker pattern for system resilience

### Security (OWASP Top 10 Compliance)
- Header injection prevention with CRLF detection
- Certificate pinning with validation and backup pins
- Secure token storage via iOS Keychain Services
- Input validation and output encoding
- Security headers enforcement (CSP, HSTS, X-Frame-Options)
- SHA-256 based checksums (MD5/SHA1 deprecated)

### Code Generation
- Macro-based API client generation
- Automatic request/response mapping
- Type-safe parameter binding
- Protocol-driven development

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/brunogama/Networking.git", from: "1.0.0")
]
```

## Quick Start

### Basic Client Configuration

```swift
import Networking

let client = NetworkClient {
    BaseURL("https://api.example.com")
    EnableLogging()
    EnableRetry()
    DefaultHeader("User-Agent", "MyApp/1.0")
    BearerAuth("your-token")
}
```

### Making Requests

```swift
// GET request
let response = try await client.execute {
    GET("/users/123")
    Timeout(15.0)
}

let user: User = try response.decode(User.self)

// POST request
let createResponse = try await client.execute {
    POST("/users")
    JSONBody(newUser)
    ContentType(.json)
}
```

### Generated API Client

```swift
@API(baseURL: "https://api.example.com")
protocol UserAPI {
    @GET("/users/{id}")
    func getUser(@Path id: String) async throws -> User
    
    @POST("/users")
    func createUser(@Body user: User) async throws -> User
    
    @PUT("/users/{id}")
    func updateUser(@Path id: String, @Body user: User) async throws -> User
    
    @DELETE("/users/{id}")
    func deleteUser(@Path id: String) async throws -> Void
}

let userAPI = UserAPIImplementation()
let user = try await userAPI.getUser(id: "123")
```

## Architecture

### Middleware System

The framework includes comprehensive middleware for:

- **Authentication**: Automatic token refresh and management
- **Retry Logic**: Exponential backoff with jitter
- **Caching**: Multi-level with TTL and storage policies
- **Logging**: Request/response logging with privacy controls
- **Metrics**: Performance tracking and monitoring
- **Security**: Header validation and sanitization

### Request Building

```swift
let request = HTTPRequest {
    GET("/api/data")
    BearerAuth(token)
    JSONBody(payload)
    Header("Custom-Header", "value")
    QueryParam("filter", "active")
    Timeout(30.0)
}
```

### Response Processing

```swift
let response = try await client.execute(request)
    .validateStatusCode()
    .transform { data in
        return try JSONDecoder().decode(Model.self, from: data)
    }
    .retry(maxAttempts: 3)
```

## Advanced Features

### File Operations

```swift
// Upload with progress tracking
let uploadTask = client.uploadFile(
    url: "/upload",
    fileURL: localFileURL,
    progressHandler: { progress in
        print("Upload progress: \(progress.fractionCompleted)")
    }
)

// Download with resume support
let downloadTask = client.downloadFile(
    url: "/download/file.zip",
    destination: destinationURL
)
```

### Circuit Breaker

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    CircuitBreaker(
        failureThreshold: 5,
        recoveryTimeout: 60.0,
        successThreshold: 3
    )
}
```

### Caching

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    EnableCaching(
        policy: .returnCacheDataElseLoad,
        storage: .memory(maxSize: 100_000_000)
    )
}
```

## Platform Support

- iOS 16.0+
- macOS 13.0+
- tvOS 16.0+
- watchOS 9.0+

## Requirements

- Swift 6.0+
- Xcode 16.0+

## Documentation

Comprehensive documentation is available through DocC:

- [Getting Started Guide](Documentation/GETTING_STARTED.md)
- [API Reference](Documentation/API_REFERENCE.md)
- [Architecture Guide](Documentation/ARCHITECTURE_GUIDE.md)
- [Security Features](Documentation/SWIFT_6_FEATURES.md)
- [Testing Guide](Documentation/TESTING_GUIDE.md)
- [Migration Guide](Documentation/MIGRATION_GUIDE.md)
- [Advanced Usage](Documentation/ADVANCED_USAGE.md)

## Testing

The framework includes comprehensive test coverage:

```bash
swift test
```

For detailed testing documentation, see [Testing Guide](Documentation/TESTING_GUIDE.md).

## Contributing

This project follows Swift API Design Guidelines and maintains Swift 6 strict concurrency compliance. See [CHANGELOG.md](CHANGELOG.md) for version history.

## License

This project is available under the MIT license.

## Version

- Framework Version: 1.0.0
- Swift Version: 6.0
- Platform Support: iOS 16+, macOS 13+, tvOS 16+, watchOS 9+