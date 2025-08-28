# Networking API Reference

## Table of Contents

1. [Core Types](#core-types)
2. [HTTPClient Protocol](#httpclient-protocol)
3. [NetworkClient](#networkclient)
4. [Request Building](#request-building)
5. [Response Processing](#response-processing)
6. [Error Handling](#error-handling)
7. [Middleware System](#middleware-system)
8. [Macros](#macros)
9. [Configuration DSL](#configuration-dsl)

---

## Core Types

### HTTPRequest

Represents an HTTP request with all necessary components.

```swift
public struct HTTPRequest: Sendable {
    public let method: HTTPMethod
    public let url: URL
    public let headers: [String: String]
    public let body: Data?
    public let timeout: TimeInterval
    
    public init(
        method: HTTPMethod,
        url: URL,
        headers: [String: String] = [:],
        body: Data? = nil,
        timeout: TimeInterval = 30.0
    )
}
```

**Properties:**
- `method`: HTTP method (GET, POST, PUT, DELETE, etc.)
- `url`: Complete URL for the request
- `headers`: HTTP headers as key-value pairs
- `body`: Optional request body data
- `timeout`: Request timeout in seconds (default: 30.0)

### HTTPResponse

Represents an HTTP response with decoded status and headers.

```swift
public struct HTTPResponse: Sendable {
    public let request: HTTPRequest
    public let status: HTTPStatus
    public let headers: [String: String]
    public let body: Data?
    
    // Convenience methods
    public func decode<T: Decodable>(_ type: T.Type) throws -> T
    public func string(encoding: String.Encoding = .utf8) -> String?
    public var isSuccess: Bool { status.isSuccess }
}
```

**Key Methods:**

#### `decode(_:)`
Decodes JSON response body to specified type.
```swift
let user: User = try response.decode(User.self)
```

#### `string(encoding:)`
Converts response body to string.
```swift
let text = response.string() // Uses UTF-8 by default
```

### HTTPMethod

Enumeration of supported HTTP methods.

```swift
public enum HTTPMethod: String, Sendable, CaseIterable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
    case head = "HEAD"
    case options = "OPTIONS"
}
```

### HTTPStatus

Type-safe representation of HTTP status codes.

```swift
public struct HTTPStatus: Sendable, Hashable {
    public let rawValue: Int
    
    // Common status codes
    public static let ok = HTTPStatus(rawValue: 200)
    public static let created = HTTPStatus(rawValue: 201)
    public static let badRequest = HTTPStatus(rawValue: 400)
    public static let unauthorized = HTTPStatus(rawValue: 401)
    public static let notFound = HTTPStatus(rawValue: 404)
    public static let serverError = HTTPStatus(rawValue: 500)
    
    // Convenience properties
    public var isSuccess: Bool { (200..<300).contains(rawValue) }
    public var isClientError: Bool { (400..<500).contains(rawValue) }
    public var isServerError: Bool { (500..<600).contains(rawValue) }
}
```

---

## HTTPClient Protocol

The foundation protocol for all HTTP operations.

```swift
public protocol HTTPClient: Sendable {
    func execute(_ request: HTTPRequest) async throws -> HTTPResponse
}
```

### Implementation Requirements

Any HTTPClient implementation must:
- Be `Sendable` for Swift 6 compliance
- Handle async execution with proper error propagation
- Support structured concurrency and cancellation

---

## NetworkClient

The main HTTP client implementation with middleware support.

### Basic Initialization

```swift
public final class NetworkClient: HTTPClient {
    public init(
        session: URLSession = .shared,
        requestMiddlewares: [any HTTPRequestMiddleware] = [],
        responseMiddlewares: [any HTTPResponseMiddleware] = [],
        errorMiddlewares: [any HTTPErrorMiddleware] = []
    )
}
```

### Builder Pattern Initialization

```swift
public convenience init(@NetworkClientBuilder _ content: () -> [any ConfigurationComponent])
```

**Example:**
```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    EnableLogging()
    EnableRetry()
    DefaultHeader("User-Agent", "MyApp/1.0")
}
```

### Executing Requests

#### Direct Execution
```swift
let request = HTTPRequest(method: .get, url: URL(string: "https://api.example.com/users")!)
let response = try await client.execute(request)
```

#### With Request Builder
```swift
let response = try await client.execute {
    GET("/users/123")
    BearerAuth(token)
    Timeout(15.0)
}
```

---

## Request Building

### RequestBuilder

Result builder for constructing HTTP requests with a fluent API.

```swift
@resultBuilder
public struct RequestBuilder {
    public static func build(@RequestBuilder _ content: () -> [any RequestComponent]) throws -> HTTPRequest
}
```

### Request Components

#### HTTP Method Components

**GET**
```swift
public struct GET: RequestComponent {
    public init(_ path: String)
}
```

**POST**
```swift
public struct POST: RequestComponent {
    public init(_ path: String)
}
```

**PUT, DELETE** - Similar pattern for other HTTP methods.

#### Header Components

**BearerAuth**
```swift
public struct BearerAuth: RequestComponent {
    public init(_ token: String)
}

// Usage
BearerAuth("your-jwt-token")
```

**BasicAuth**
```swift
public struct BasicAuth: RequestComponent {
    public init(username: String, password: String)
}

// Usage
BasicAuth(username: "user", password: "pass")
```

**Custom Headers**
```swift
public struct Header: RequestComponent {
    public init(_ name: String, _ value: String)
}

// Usage
Header("X-API-Key", "your-api-key")
```

#### Body Components

**JSONBody**
```swift
public struct JSONBody<T: Encodable>: RequestComponent {
    public init(_ value: T)
}

// Usage
let user = User(name: "John", email: "john@example.com")
JSONBody(user)
```

**DataBody**
```swift
public struct DataBody: RequestComponent {
    public init(_ data: Data)
    public init(_ string: String, encoding: String.Encoding = .utf8)
}

// Usage
DataBody("Raw string content")
DataBody(customData)
```

#### Query Parameters

**QueryParam**
```swift
public struct QueryParam: RequestComponent {
    public init(_ name: String, _ value: String)
}

// Usage
QueryParam("limit", "10")
QueryParam("offset", "20")
```

#### Configuration Components

**Timeout**
```swift
public struct Timeout: RequestComponent {
    public init(_ seconds: TimeInterval)
}

// Usage
Timeout(30.0)
```

### Usage Examples

#### Simple GET Request
```swift
let response = try await client.execute {
    GET("/users")
    Header("Accept", "application/json")
    Timeout(10.0)
}
```

#### POST with JSON Body
```swift
let response = try await client.execute {
    POST("/users")
    BearerAuth(authToken)
    JSONBody(newUser)
    Header("Content-Type", "application/json")
}
```

#### Complex Request with Multiple Parameters
```swift
let response = try await client.execute {
    GET("/search")
    QueryParam("q", searchTerm)
    QueryParam("limit", "20")
    QueryParam("sort", "created_at")
    BearerAuth(token)
    Timeout(15.0)
}
```

---

## Response Processing

### HTTPResponseBuilder

Result builder for processing HTTP responses with a fluent pipeline API.

```swift
@resultBuilder
public struct HTTPResponseBuilder {
    public static func build(
        @HTTPResponseBuilder _ content: () -> [any ResponseProcessor]
    ) -> ResponseProcessingChain
}
```

### Response Processors

#### Validation Processors

**StatusCodeValidator**
```swift
public struct StatusCodeValidator: ResponseProcessor {
    public init(_ validCodes: [HTTPStatus])
    public init(_ range: Range<Int>)
}

// Usage
StatusCodeValidator([.ok, .created, .accepted])
StatusCodeValidator(200..<300)
```

**ContentTypeValidator**
```swift
public struct ContentTypeValidator: ResponseProcessor {
    public init(_ expectedType: String)
}

// Usage
ContentTypeValidator("application/json")
```

#### Transformation Processors

**JSONDecoder**
```swift
public struct JSONDecoder<T: Decodable>: ResponseProcessor {
    public init(_ type: T.Type)
    public init(_ type: T.Type, decoder: Foundation.JSONDecoder)
}

// Usage
JSONDecoder(User.self)
```

**DataExtractor**
```swift
public struct DataExtractor: ResponseProcessor {
    public init()
}
```

#### Error Handling Processors

**ErrorMapper**
```swift
public struct ErrorMapper: ResponseProcessor {
    public init(_ mapper: @escaping (HTTPResponse) -> Error?)
}

// Usage
ErrorMapper { response in
    if response.status == .unauthorized {
        return AuthenticationError()
    }
    return nil
}
```

### Usage Examples

#### Basic Response Processing
```swift
let user: User = try await client.execute {
    GET("/users/123")
    BearerAuth(token)
}.process {
    StatusCodeValidator(.ok)
    ContentTypeValidator("application/json")
    JSONDecoder(User.self)
}
```

#### Complex Response Pipeline
```swift
let result = try await client.execute {
    POST("/data")
    JSONBody(requestData)
}.process {
    StatusCodeValidator(200..<300)
    
    // Custom validation
    CustomValidator { response in
        guard response.headers["X-Rate-Limit-Remaining"] != "0" else {
            throw RateLimitError()
        }
    }
    
    // Transform response
    JSONDecoder(APIResponse.self)
    
    // Extract nested data
    DataTransformer { apiResponse in
        apiResponse.data
    }
}
```

---

## Error Handling

### HTTPError

Comprehensive error type with contextual information.

```swift
public struct HTTPError: Error, Sendable, LocalizedError {
    public let category: Category
    public let request: HTTPRequest?
    public let response: HTTPResponse?
    public let underlyingError: (any Error)?
}
```

### Error Categories

```swift
public enum Category: Sendable, Hashable {
    case network(NetworkError)
    case http(HTTPStatus)
    case decoding(String)
    case encoding(String)
    case timeout
    case cancelled
    case configuration(String)
}

public enum NetworkError: Sendable, Hashable {
    case noConnection
    case dnsFailure
    case connectionLost
    case serverUnreachable
    case sslError
}
```

### Error Severity and Recovery

```swift
public enum ErrorSeverity: Sendable, CaseIterable {
    case low        // Can be ignored or handled gracefully
    case medium     // Should be logged and handled  
    case high       // Requires immediate attention
    case critical   // System-threatening, requires emergency handling
}

public enum RecoveryCategory: Sendable, CaseIterable {
    case retryable                // Can be retried immediately
    case retryableWithDelay       // Can be retried after a delay
    case userActionRequired       // Requires user intervention
    case nonRecoverable          // Cannot be recovered from
}
```

### Error Extensions

```swift
extension HTTPError {
    public var severity: ErrorSeverity { ... }
    public var recoveryCategory: RecoveryCategory { ... }
    public var isRetryable: Bool { ... }
    public var requiresUserAction: Bool { ... }
}
```

### Error Handling Examples

#### Basic Error Handling
```swift
do {
    let user = try await client.execute {
        GET("/users/123")
        BearerAuth(token)
    }.decode(User.self)
} catch let error as HTTPError {
    switch error.category {
    case .network(.noConnection):
        // Handle network connectivity issues
        showOfflineMode()
        
    case .http(let status) where status == .unauthorized:
        // Handle authentication errors
        redirectToLogin()
        
    case .http(let status) where status == .notFound:
        // Handle resource not found
        showUserNotFoundError()
        
    case .decoding(let message):
        // Handle JSON parsing errors
        logDecodingError(message)
        
    default:
        // Handle other errors
        showGenericError(error)
    }
}
```

#### Advanced Error Recovery
```swift
func fetchUserWithRecovery(id: String) async throws -> User {
    do {
        return try await client.execute {
            GET("/users/\(id)")
            BearerAuth(authToken)
        }.decode(User.self)
    } catch let error as HTTPError {
        switch error.recoveryCategory {
        case .retryable:
            // Immediate retry
            return try await fetchUserWithRecovery(id: id)
            
        case .retryableWithDelay:
            // Retry after delay
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            return try await fetchUserWithRecovery(id: id)
            
        case .userActionRequired:
            // Prompt user for action (e.g., re-authentication)
            try await reauthenticate()
            return try await fetchUserWithRecovery(id: id)
            
        case .nonRecoverable:
            // Cannot recover, propagate error
            throw error
        }
    }
}
```

---

## Middleware System

### Middleware Types

The framework supports three types of middleware:

#### HTTPRequestMiddleware
Modifies requests before execution.

```swift
public protocol HTTPRequestMiddleware: Sendable {
    func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest
}
```

#### HTTPResponseMiddleware  
Processes responses after execution.

```swift
public protocol HTTPResponseMiddleware: Sendable {
    func processResponse(
        _ response: HTTPResponse, 
        for request: HTTPRequest
    ) async throws -> HTTPResponse
}
```

#### HTTPErrorMiddleware
Handles errors during request execution.

```swift
public protocol HTTPErrorMiddleware: Sendable {
    func handleError(
        _ error: HTTPError, 
        for request: HTTPRequest
    ) async throws -> HTTPResponse
}
```

### Built-in Middleware

#### LoggingMiddleware
Logs request and response details.

```swift
public struct LoggingMiddleware: HTTPRequestMiddleware, HTTPResponseMiddleware {
    public struct Configuration {
        public var logLevel: LogLevel = .info
        public var logHeaders: Bool = true
        public var logBody: Bool = false
        public var maxBodyLength: Int = 1024
    }
    
    public init(configuration: Configuration = Configuration())
}
```

#### AuthenticationMiddleware
Handles token-based authentication with automatic refresh.

```swift
public struct AuthenticationMiddleware: HTTPRequestMiddleware, HTTPErrorMiddleware {
    public struct Configuration {
        public var authorizationHeaderName: String = "Authorization"
        public var tokenPrefix: String = "Bearer "
        public var maxRefreshAttempts: Int = 1
    }
    
    public init(
        configuration: Configuration,
        tokenProvider: any TokenProvider,
        client: any HTTPClient
    )
}
```

#### RetryMiddleware
Implements retry logic with exponential backoff.

```swift
public struct RetryMiddleware: HTTPErrorMiddleware {
    public struct Configuration {
        public var maxAttempts: Int = 3
        public var baseDelay: TimeInterval = 1.0
        public var maxDelay: TimeInterval = 60.0
        public var backoffMultiplier: Double = 2.0
        public var jitterStrategy: JitterStrategy = .equal
        public var shouldRetry: (HTTPError, Int) -> Bool
    }
    
    public init(
        configuration: Configuration,
        client: any HTTPClient
    )
}
```

#### CachingMiddleware
Provides response caching with TTL support.

```swift
public struct CachingMiddleware: HTTPRequestMiddleware, HTTPResponseMiddleware {
    public struct Configuration {
        public var defaultTTL: TimeInterval = 300.0
        public var useConditionalRequests: Bool = true
        public var shouldCache: (HTTPRequest, HTTPResponse) -> Bool
    }
    
    public init(
        configuration: Configuration,
        storage: any CacheStorage
    )
}
```

#### CircuitBreakerMiddleware
Implements circuit breaker pattern for fault tolerance.

```swift
public struct CircuitBreakerMiddleware: HTTPErrorMiddleware {
    public struct Configuration {
        public var failureThreshold: Int = 5
        public var recoveryTimeout: TimeInterval = 60.0
        public var successThreshold: Int = 3
        public var rollingWindow: TimeInterval = 120.0
    }
    
    public init(
        configuration: Configuration,
        client: any HTTPClient
    )
}
```

### Custom Middleware Examples

#### Request ID Middleware
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
```

#### Response Time Middleware
```swift
struct ResponseTimeMiddleware: HTTPResponseMiddleware {
    func processResponse(
        _ response: HTTPResponse,
        for request: HTTPRequest
    ) async throws -> HTTPResponse {
        let responseTime = response.headers["X-Response-Time"] ?? "0"
        print("Request to \(request.url) took \(responseTime)ms")
        return response
    }
}
```

---

## Macros

The framework provides Swift macros for generating type-safe API clients.

### @API Macro

Generates API client implementation from protocol definitions.

```swift
@attached(extension)
public macro API(baseURL: String)
```

**Example:**
```swift
@API(baseURL: "https://api.example.com")
protocol UserAPI {
    @GET("/users/{id}")
    func getUser(@Path id: String) async throws -> User
    
    @POST("/users")
    func createUser(@Body user: User) async throws -> User
}

// Generated implementation available as:
let userAPI = UserAPIImplementation()
```

### HTTP Method Macros

#### @GET, @POST, @PUT, @DELETE
```swift
@attached(peer)
public macro GET(_ path: String)

@attached(peer)
public macro POST(_ path: String)

@attached(peer)
public macro PUT(_ path: String)

@attached(peer)
public macro DELETE(_ path: String)
```

### Parameter Macros

#### @Path
Marks a parameter as a URL path parameter.

```swift
@attached(peer)
public macro Path(_ name: String? = nil)

// Usage
@GET("/users/{id}/posts/{postId}")
func getUserPost(
    @Path id: String,
    @Path("postId") postID: String
) async throws -> Post
```

#### @Body
Marks a parameter as the request body.

```swift
@attached(peer)
public macro Body()

// Usage
@POST("/users")
func createUser(@Body user: User) async throws -> User
```

#### @Query
Marks a parameter as a query parameter.

```swift
@attached(peer)
public macro Query(_ name: String? = nil)

// Usage
@GET("/users")
func getUsers(
    @Query limit: Int,
    @Query("offset") startIndex: Int
) async throws -> [User]
```

#### @Header
Marks a parameter as a header value.

```swift
@attached(peer)
public macro Header(_ name: String)

// Usage
@GET("/protected")
func getProtectedData(
    @Header("Authorization") auth: String
) async throws -> ProtectedData
```

### Caching Macros

#### @Cacheable
Marks a method as cacheable.

```swift
@attached(peer)
public macro Cacheable(
    ttl: TimeInterval? = nil,
    tags: [String] = [],
    key: String? = nil
)

// Usage
@GET("/users/{id}")
@Cacheable(ttl: 300, tags: ["user"])
func getUser(@Path id: String) async throws -> User
```

#### @CacheInvalidation
Marks a method as causing cache invalidation.

```swift
@attached(peer)
public macro CacheInvalidation(
    tags: [String] = [],
    pattern: String? = nil,
    keys: [String] = []
)

// Usage
@POST("/users")
@CacheInvalidation(tags: ["user"], pattern: "users/*")
func createUser(@Body user: User) async throws -> User
```

### Complete API Example

```swift
@API(baseURL: "https://api.example.com")
protocol BlogAPI {
    // Get all posts with pagination and caching
    @GET("/posts")
    @Cacheable(ttl: 180, tags: ["posts"])
    func getPosts(
        @Query limit: Int = 20,
        @Query offset: Int = 0,
        @Query category: String?
    ) async throws -> PostsResponse
    
    // Get specific post with caching
    @GET("/posts/{id}")
    @Cacheable(ttl: 300, tags: ["post"])
    func getPost(@Path id: String) async throws -> Post
    
    // Create new post (invalidates cache)
    @POST("/posts")
    @CacheInvalidation(tags: ["posts", "post"])
    func createPost(
        @Body post: CreatePostRequest,
        @Header("Authorization") token: String
    ) async throws -> Post
    
    // Update post (invalidates specific post cache)
    @PUT("/posts/{id}")
    @CacheInvalidation(keys: ["post-{id}"])
    func updatePost(
        @Path id: String,
        @Body post: UpdatePostRequest
    ) async throws -> Post
    
    // Delete post
    @DELETE("/posts/{id}")
    @CacheInvalidation(pattern: "post*")
    func deletePost(@Path id: String) async throws
}

// Usage
let blogAPI = BlogAPIImplementation()

// All operations are now type-safe and async
let posts = try await blogAPI.getPosts(limit: 10, category: "tech")
let post = try await blogAPI.getPost(id: "123")
let newPost = try await blogAPI.createPost(
    post: CreatePostRequest(title: "New Post", content: "..."),
    token: "Bearer \(authToken)"
)
```

---

## Configuration DSL

### NetworkClientBuilder

Result builder for configuring NetworkClient instances.

```swift
@resultBuilder
public struct NetworkClientBuilder {
    public static func buildBlock(_ components: any ConfigurationComponent...) -> [any ConfigurationComponent]
}
```

### Core Configuration Components

#### BaseURL
```swift
public struct BaseURL: ConfigurationComponent {
    public init(_ url: String)
    public init(_ url: URL)
}
```

#### Default Headers
```swift
public struct DefaultHeader: ConfigurationComponent {
    public init(_ name: String, _ value: String)
}

public struct DefaultTimeout: ConfigurationComponent {
    public init(_ seconds: TimeInterval)
}
```

#### Logging Configuration
```swift
public struct EnableLogging: ConfigurationComponent {
    public init(_ configuration: LoggingMiddleware.Configuration = .default)
}
```

### Advanced Configuration Blocks

#### Authentication Block
```swift
public struct Authentication: ConfigurationComponent {
    public init(@AuthenticationBuilder _ content: () -> [any AuthenticationComponent])
}

// Usage
Authentication {
    BearerToken("your-token")
    RefreshStrategy.automatic()
    AuthenticateWhen.always()
}
```

#### Retry Block
```swift
public struct Retry: ConfigurationComponent {
    public init(@RetryBuilder _ content: () -> [any RetryComponent])
}

// Usage
Retry {
    MaxAttempts(3)
    BackoffStrategy.exponential()
    InitialDelay(1.0)
    RetryWhen.networkErrors()
}
```

#### Caching Block
```swift
public struct Caching: ConfigurationComponent {
    public init(@CachingBuilder _ content: () -> [any CachingComponent])
}

// Usage
Caching {
    Policy.standard()
    Storage.memory(size: .MB(50))
    Duration.ttl(300)
    CacheWhen.getRequestsOnly()
}
```

#### Session Block
```swift
public struct Session: ConfigurationComponent {
    public init(@SessionBuilder _ content: () -> [any SessionComponent])
}

// Usage
Session {
    SessionTimeout(60.0)
    AllowsCellular(true)
    AllowsExpensiveNetworkAccess(false)
    WaitsForConnectivity(true)
}
```

### Complete Configuration Example

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    DefaultHeader("User-Agent", "MyApp/1.0")
    DefaultHeader("Accept", "application/json")
    DefaultTimeout(30.0)
    
    // Authentication
    Authentication {
        BearerToken(userToken)
        RefreshStrategy.automatic()
        AuthenticateWhen.pathMatches("/api/")
    }
    
    // Retry Policy
    Retry {
        MaxAttempts(3)
        BackoffStrategy.exponential()
        InitialDelay(1.0)
        MaxDelay(30.0)
        RetryWhen.networkErrors()
    }
    
    // Caching
    Caching {
        Policy.standard()
        Storage.hybrid(
            memorySize: .MB(50),
            diskSize: .GB(1)
        )
        Duration.ttl(300)
        CacheWhen.successfulResponses()
    }
    
    // Session Configuration
    Session {
        SessionTimeout(60.0)
        AllowsCellular(true)
        AllowsExpensiveNetworkAccess(false)
        WaitsForConnectivity(true)
        MaxConnectionsPerHost(6)
        RequestCachePolicy(.useProtocolCachePolicy)
    }
    
    // Enable logging in debug builds
    #if DEBUG
    EnableLogging(LoggingMiddleware.Configuration(
        logLevel: .debug,
        logHeaders: true,
        logBody: true
    ))
    #endif
}
```

This configuration creates a fully-featured HTTP client with authentication, intelligent retry logic, response caching, optimized session settings, and debug logging.