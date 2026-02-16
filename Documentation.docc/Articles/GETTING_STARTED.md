# Networking - Getting Started Guide

## Table of Contents

1. [Installation](#installation)
2. [Quick Start](#quick-start)
3. [Basic Concepts](#basic-concepts)
4. [Your First Request](#your-first-request)
5. [Configuration](#configuration)
6. [Common Patterns](#common-patterns)
7. [Error Handling](#error-handling)
8. [Advanced Features](#advanced-features)
9. [Next Steps](#next-steps)

---

## Installation

### Swift Package Manager

Add Networking to your `Package.swift`:

```swift
// Package.swift
let package = Package(
    name: "YourProject",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .tvOS(.v16),
        .watchOS(.v9)
    ],
    dependencies: [
        .package(url: "https://github.com/brunogama/Networking.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "YourProject",
            dependencies: ["Networking"]
        )
    ]
)
```

### Xcode Integration

1. In Xcode, go to **File → Add Package Dependencies**
2. Enter the repository URL: `https://github.com/brunogama/Networking.git`
3. Select the version range and add to your target

### Requirements

- **iOS 16.0+** / **macOS 13.0+** / **tvOS 16.0+** / **watchOS 9.0+**
- **Swift 6.0+**
- **Xcode 16.0+**

---

## Quick Start

### Import the Framework

```swift
import Networking
```

### Create Your First Client

```swift
let client = NetworkClient {
    BaseURL("https://jsonplaceholder.typicode.com")
    DefaultHeader("Accept", "application/json")
    EnableLogging()
}
```

### Make Your First Request

```swift
struct Post: Codable {
    let id: Int
    let title: String
    let body: String
    let userId: Int
}

// Async function to fetch a post
func fetchPost(id: Int) async throws -> Post {
    let response = try await client.execute {
        GET("/posts/\(id)")
        Timeout(10.0)
    }
    
    return try response.decode(Post.self)
}

// Usage
Task {
    do {
        let post = try await fetchPost(id: 1)
        print("Post title: \(post.title)")
    } catch {
        print("Error: \(error)")
    }
}
```

---

## Basic Concepts

### 1. HTTPClient Protocol

The foundation of all networking operations:

```swift
public protocol HTTPClient: Sendable {
    func execute(_ request: HTTPRequest) async throws -> HTTPResponse
}
```

### 2. NetworkClient

The main implementation that handles:
- Request execution
- Middleware processing
- Error handling
- Response processing

### 3. Request Builders

Fluent DSL for building requests:

```swift
let response = try await client.execute {
    GET("/users/123")                    // HTTP method and path
    Header("Authorization", "Bearer ...") // Custom headers
    QueryParam("include", "profile")     // Query parameters  
    Timeout(15.0)                        // Request timeout
}
```

### 4. Middleware System

Composable components that process requests, responses, and errors:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    EnableLogging()        // Request/response logging
    EnableRetry()          // Automatic retries
    Authentication {       // Token-based auth
        BearerToken(token)
    }
}
```

---

## Your First Request

Let's walk through creating different types of requests:

### GET Request

```swift
// Simple GET request
let response = try await client.execute {
    GET("/users")
}

// GET with query parameters
let response = try await client.execute {
    GET("/users")
    QueryParam("page", "1")
    QueryParam("limit", "20")
    QueryParam("sort", "name")
}

// Decode JSON response
struct User: Codable {
    let id: Int
    let name: String
    let email: String
}

let users: [User] = try response.decode([User].self)
```

### POST Request

```swift
// POST with JSON body
struct CreateUserRequest: Codable {
    let name: String
    let email: String
    let role: String
}

let newUser = CreateUserRequest(
    name: "John Doe",
    email: "john@example.com",
    role: "user"
)

let response = try await client.execute {
    POST("/users")
    JSONBody(newUser)
    Header("Content-Type", "application/json")
}

let createdUser: User = try response.decode(User.self)
```

### PUT Request

```swift
// PUT for updates
struct UpdateUserRequest: Codable {
    let name: String?
    let email: String?
}

let updateData = UpdateUserRequest(
    name: "Jane Doe",
    email: nil  // Don't update email
)

let response = try await client.execute {
    PUT("/users/123")
    JSONBody(updateData)
    BearerAuth(authToken)
}
```

### DELETE Request

```swift
// DELETE request
let response = try await client.execute {
    DELETE("/users/123")
    BearerAuth(authToken)
}

// Check if deletion was successful
if response.status == .ok || response.status == .noContent {
    print("User deleted successfully")
}
```

---

## Configuration

### Basic Client Configuration

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")           // Base URL for all requests
    DefaultHeader("User-Agent", "MyApp/1.0")     // Default headers
    DefaultHeader("Accept", "application/json")   
    DefaultTimeout(30.0)                         // Default timeout
    EnableLogging()                              // Enable request/response logging
}
```

### Authentication Configuration

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    
    Authentication {
        BearerToken(userToken)                   // Static token
        RefreshStrategy.automatic()              // Auto-refresh on 401
        AuthenticateWhen.always()               // Authenticate all requests
    }
}

// Or with basic auth
let client = NetworkClient {
    BaseURL("https://api.example.com")
    
    Authentication {
        BasicAuth(username: "user", password: "pass")
    }
}
```

### Retry Configuration

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    
    Retry {
        MaxAttempts(3)                          // Retry up to 3 times
        BackoffStrategy.exponential()           // Exponential backoff
        InitialDelay(1.0)                      // Start with 1 second delay
        MaxDelay(30.0)                         // Cap at 30 seconds
        RetryWhen.networkErrors()              // Only retry network errors
    }
}
```

### Caching Configuration

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    
    Caching {
        Policy.standard()                       // Standard HTTP caching
        Storage.memory(size: .MB(50))          // 50MB memory cache
        Duration.ttl(300)                      // 5 minute TTL
        CacheWhen.getRequestsOnly()            // Only cache GET requests
    }
}
```

### Session Configuration

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    
    Session {
        SessionTimeout(60.0)                   // 60 second timeout
        AllowsCellular(true)                   // Allow cellular data
        AllowsExpensiveNetworkAccess(false)    // Block expensive network
        WaitsForConnectivity(true)             // Wait for network
        MaxConnectionsPerHost(6)               // Connection pooling
    }
}
```

---

## Common Patterns

### 1. API Client Class

Create a dedicated API client for your service:

```swift
class GitHubAPIClient {
    private let client: NetworkClient
    
    init(token: String) {
        self.client = NetworkClient {
            BaseURL("https://api.github.com")
            DefaultHeader("Accept", "application/vnd.github.v3+json")
            DefaultHeader("User-Agent", "MyApp/1.0")
            
            Authentication {
                BearerToken(token)
            }
            
            Retry {
                MaxAttempts(3)
                RetryWhen.networkErrors()
            }
        }
    }
    
    func getUser(username: String) async throws -> GitHubUser {
        let response = try await client.execute {
            GET("/users/\(username)")
        }
        return try response.decode(GitHubUser.self)
    }
    
    func getUserRepos(username: String, page: Int = 1) async throws -> [GitHubRepo] {
        let response = try await client.execute {
            GET("/users/\(username)/repos")
            QueryParam("page", "\(page)")
            QueryParam("per_page", "50")
            QueryParam("sort", "updated")
        }
        return try response.decode([GitHubRepo].self)
    }
}
```

### 2. Response Processing Pipeline

Process responses with validation and transformation:

```swift
let user: User = try await client.execute {
    GET("/users/123")
    BearerAuth(token)
}.process {
    // Validate status codes
    StatusCodeValidator(200..<300)
    
    // Validate content type
    ContentTypeValidator("application/json")
    
    // Custom validation
    CustomValidator { response in
        guard let rateLimitRemaining = response.headers["X-RateLimit-Remaining"],
              Int(rateLimitRemaining) ?? 0 > 0 else {
            throw APIError.rateLimitExceeded
        }
    }
    
    // Decode JSON
    JSONDecoder(User.self)
}
```

### 3. Pagination Handling

Handle paginated API responses:

```swift
func fetchAllUsers() async throws -> [User] {
    var allUsers: [User] = []
    var page = 1
    var hasMore = true
    
    while hasMore {
        let response = try await client.execute {
            GET("/users")
            QueryParam("page", "\(page)")
            QueryParam("limit", "100")
        }
        
        struct UsersResponse: Codable {
            let users: [User]
            let hasMore: Bool
            let totalPages: Int
        }
        
        let usersResponse = try response.decode(UsersResponse.self)
        allUsers.append(contentsOf: usersResponse.users)
        
        hasMore = usersResponse.hasMore
        page += 1
    }
    
    return allUsers
}
```

### 4. File Upload

First, let's define the multipart body components:

```swift
struct MultipartBody: RequestComponent {
    let fields: [MultipartField]
    
    init(@MultipartBuilder content: () -> [MultipartField]) {
        self.fields = content()
    }
    
    func build(into request: inout HTTPRequest) throws {
        // Implementation would generate multipart/form-data body
        request.body = try generateMultipartData(fields: fields)
        request.headers["Content-Type"] = "multipart/form-data; boundary=\(boundary)"
    }
}

struct MultipartField {
    let name: String
    let data: Data?
    let value: String?
    let mimeType: String?
    let filename: String?
    
    init(name: String, data: Data, mimeType: String? = nil, filename: String? = nil) {
        self.name = name
        self.data = data
        self.value = nil
        self.mimeType = mimeType
        self.filename = filename
    }
    
    init(name: String, value: String) {
        self.name = name
        self.data = nil
        self.value = value
        self.mimeType = nil
        self.filename = nil
    }
}

@resultBuilder
struct MultipartBuilder {
    static func buildBlock(_ components: MultipartField...) -> [MultipartField] {
        Array(components)
    }
}
```

Upload files with progress tracking:

```swift
func uploadAvatar(imageData: Data, userId: String) async throws -> UploadResponse {
    let response = try await client.execute {
        POST("/users/\(userId)/avatar")
        BearerAuth(authToken)
        
        // Multipart form data
        MultipartBody {
            MultipartField(name: "avatar", data: imageData, mimeType: "image/jpeg")
            MultipartField(name: "user_id", value: userId)
        }
        
        // Extended timeout for uploads
        Timeout(120.0)
    }
    
    return try response.decode(UploadResponse.self)
}
```

### 5. Concurrent Requests

Make multiple requests concurrently:

```swift
func fetchUserData(userId: String) async throws -> UserData {
    async let profile = client.execute {
        GET("/users/\(userId)")
        BearerAuth(authToken)
    }
    
    async let posts = client.execute {
        GET("/users/\(userId)/posts")
        BearerAuth(authToken)
    }
    
    async let followers = client.execute {
        GET("/users/\(userId)/followers")
        BearerAuth(authToken)
    }
    
    // Wait for all requests to complete
    let (profileResponse, postsResponse, followersResponse) = try await (profile, posts, followers)
    
    return UserData(
        profile: try profileResponse.decode(UserProfile.self),
        posts: try postsResponse.decode([Post].self),
        followers: try followersResponse.decode([User].self)
    )
}
```

---

## Error Handling

### Understanding HTTPError

```swift
do {
    let user = try await fetchUser(id: "123")
    // Use user data
} catch let error as HTTPError {
    switch error.category {
    case .network(let networkError):
        // Handle network issues
        switch networkError {
        case .noConnection:
            showOfflineMessage()
        case .dnsFailure:
            showDNSErrorMessage()
        case .serverUnreachable:
            showServerErrorMessage()
        default:
            showGenericNetworkError()
        }
        
    case .http(let status):
        // Handle HTTP status errors
        switch status.rawValue {
        case 400:
            showBadRequestError()
        case 401:
            redirectToLogin()
        case 403:
            showUnauthorizedError()
        case 404:
            showNotFoundError()
        case 500...599:
            showServerErrorMessage()
        default:
            showGenericHTTPError()
        }
        
    case .decoding(let message):
        // Handle JSON parsing errors
        print("Failed to parse response: \(message)")
        showDataParsingError()
        
    case .timeout:
        showTimeoutError()
        
    case .cancelled:
        // Request was cancelled, usually no action needed
        break
        
    case .configuration(let message):
        // Configuration error - usually a development issue
        assertionFailure("Configuration error: \(message)")
    }
}
```

### Error Recovery Patterns

```swift
func fetchUserWithRetry(id: String, maxAttempts: Int = 3) async throws -> User {
    var lastError: Error?
    
    for attempt in 1...maxAttempts {
        do {
            return try await fetchUser(id: id)
        } catch let error as HTTPError {
            lastError = error
            
            switch error.category {
            case .network:
                // Retry network errors after delay
                let delay = TimeInterval(attempt * 2) // 2, 4, 6 seconds
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
            case .http(let status) where status.rawValue >= 500:
                // Retry server errors after delay
                let delay = TimeInterval(attempt * 3) // 3, 6, 9 seconds
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
            case .http(let status) where status.rawValue == 401:
                // Try to refresh authentication
                try await refreshAuthToken()
                // Don't count this as an attempt
                continue
                
            default:
                // Don't retry client errors or other errors
                throw error
            }
        }
    }
    
    throw lastError ?? HTTPError(category: .configuration("Unknown error"))
}
```

### Global Error Handling

Set up global error handling for common scenarios:

```swift
class APIErrorHandler {
    static func handle(_ error: Error) {
        guard let httpError = error as? HTTPError else {
            // Handle non-HTTP errors
            print("Non-HTTP error: \(error)")
            return
        }
        
        switch httpError.category {
        case .http(let status) where status.rawValue == 401:
            // Global auth error handling
            NotificationCenter.default.post(name: .authenticationRequired, object: nil)
            
        case .network(.noConnection):
            // Global offline handling
            NotificationCenter.default.post(name: .networkUnavailable, object: nil)
            
        case .http(let status) where status.rawValue >= 500:
            // Global server error handling
            Analytics.logServerError(status: status.rawValue)
            
        default:
            // Log other errors for monitoring
            Analytics.logError(httpError)
        }
    }
}

// Usage in requests
do {
    let user = try await fetchUser(id: id)
    return user
} catch {
    APIErrorHandler.handle(error)
    throw error  // Re-throw for local handling
}
```

---

## Advanced Features

### 1. Generated API Clients

Use Swift macros to generate type-safe API clients:

```swift
@API(baseURL: "https://api.example.com")
protocol UserAPI {
    @GET("/users/{id}")
    @Cacheable(ttl: 300)
    func getUser(@Path id: String) async throws -> User
    
    @POST("/users")
    @CacheInvalidation(tags: ["users"])
    func createUser(@Body user: CreateUserRequest) async throws -> User
    
    @PUT("/users/{id}")
    @CacheInvalidation(keys: ["user-{id}"])
    func updateUser(
        @Path id: String, 
        @Body user: UpdateUserRequest,
        @Header("If-Match") etag: String
    ) async throws -> User
    
    @DELETE("/users/{id}")
    @CacheInvalidation(pattern: "user*")
    func deleteUser(@Path id: String) async throws
}

// Use the generated implementation
let userAPI = UserAPIImplementation()
let user = try await userAPI.getUser(id: "123")
```

### 2. Custom Middleware

Create custom middleware for specific needs:

```swift
struct RequestIDMiddleware: HTTPRequestMiddleware {
    func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
        var headers = request.headers
        headers["X-Request-ID"] = UUID().uuidString
        
        return HTTPRequest(
            method: request.method,
            url: request.url,
            headers: headers,
            body: request.body,
            timeout: request.timeout
        )
    }
}

// Add to client
let client = NetworkClient(
    requestMiddlewares: [RequestIDMiddleware()]
)
```

### 3. Request/Response Interceptors

Implement interceptors for cross-cutting concerns:

```swift
struct AnalyticsInterceptor: HTTPRequestMiddleware, HTTPResponseMiddleware {
    func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
        Analytics.trackNetworkRequest(
            method: request.method.rawValue,
            url: request.url.absoluteString
        )
        return request
    }
    
    func processResponse(_ response: HTTPResponse, for request: HTTPRequest) async throws -> HTTPResponse {
        Analytics.trackNetworkResponse(
            statusCode: response.status.rawValue,
            duration: response.requestDuration
        )
        return response
    }
}
```

### 4. Circuit Breaker Pattern

Prevent cascading failures with circuit breaker:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    
    // Circuit breaker configuration
    CircuitBreaker {
        FailureThreshold(5)         // Open after 5 failures
        RecoveryTimeout(60.0)       // Try recovery after 60 seconds
        SuccessThreshold(3)         // Close after 3 successes
    }
}
```

---

## Next Steps

### Learn More

1. **[API Reference](API_REFERENCE.md)** - Complete API documentation
2. **[Architecture Guide](ARCHITECTURE_GUIDE.md)** - Deep dive into framework architecture  
3. **[Migration Guide](MIGRATION_GUIDE.md)** - Migrating from other networking frameworks
4. **[Advanced Usage](ADVANCED_USAGE.md)** - Complex scenarios and patterns
5. **[Testing Guide](TESTING_GUIDE.md)** - Testing strategies and utilities

### Example Projects

Check out these example projects to see Networking in action:

1. **BasicNetworking** - Simple GET/POST requests
2. **GitHubClient** - Real-world API client with pagination
3. **FileUploadExample** - File upload with progress tracking
4. **RealtimeChat** - WebSocket integration example
5. **OfflineFirst** - Caching and offline capabilities

### Best Practices

1. **Use Generated API Clients** for type safety and maintainability
2. **Configure Retry Policies** for robust error handling
3. **Enable Caching** for better performance
4. **Add Request/Response Logging** for debugging
5. **Handle Errors Gracefully** with proper user feedback
6. **Use Concurrent Requests** when loading multiple resources
7. **Test with Mock Clients** for reliable unit tests

### Community

- **GitHub Issues** - Report bugs and request features
- **Discussions** - Ask questions and share experiences
- **Stack Overflow** - Tag questions with `modernnetworking-swift`
- **Swift Forums** - Join Swift community discussions

### Support

- **Documentation** - Comprehensive guides and API reference
- **Sample Code** - Working examples for common scenarios
- **Video Tutorials** - Step-by-step walkthroughs
- **Community Support** - Active community of developers

Ready to build amazing networking experiences with Networking.