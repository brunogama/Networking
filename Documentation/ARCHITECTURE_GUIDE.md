# Networking Architecture Guide

## Table of Contents

1. [Overview](#overview)
2. [Core Architecture](#core-architecture)
3. [Design Patterns](#design-patterns)
4. [Component Architecture](#component-architecture)
5. [Concurrency Model](#concurrency-model)
6. [Middleware Pipeline](#middleware-pipeline)
7. [Error Handling Strategy](#error-handling-strategy)
8. [Memory Management](#memory-management)
9. [Testing Architecture](#testing-architecture)
10. [Swift 6 Compliance](#swift-6-compliance)

---

## Overview

Networking is architected around three core principles:

1. **Swift 6 First**: Built from the ground up with Swift 6 concurrency, Sendable compliance, and actor isolation
2. **Composable Design**: Middleware-based architecture enabling easy extension and customization  
3. **Developer Experience**: Fluent DSLs, result builders, and macros for maximum productivity

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        Client Layer                         │
├─────────────────┬─────────────────┬─────────────────────────┤
│  Request DSL    │  Configuration  │     Generated APIs      │
│  @RequestBuilder│      DSL        │       @API Macro        │
└─────────────────┴─────────────────┴─────────────────────────┘
           │                │                        │
           ▼                ▼                        ▼
┌─────────────────────────────────────────────────────────────┐
│                    NetworkClient                            │
├─────────────────────────────────────────────────────────────┤
│              Middleware Pipeline                            │
│  Request → Response → Error Handling                        │
└─────────────────────────────────────────────────────────────┘
           │                │                        │
           ▼                ▼                        ▼
┌─────────────────────────────────────────────────────────────┐
│                 Core HTTP Layer                             │
├─────────────────┬─────────────────┬─────────────────────────┤
│  HTTPRequest    │  HTTPResponse   │      HTTPError          │
│  HTTPClient     │  HTTPStatus     │   Error Categories      │
└─────────────────┴─────────────────┴─────────────────────────┘
           │                │                        │
           ▼                ▼                        ▼
┌─────────────────────────────────────────────────────────────┐
│                   Foundation Layer                          │
│              URLSession + Swift Concurrency                 │
└─────────────────────────────────────────────────────────────┘
```

---

## Core Architecture

### Layered Design

The framework follows a layered architecture pattern:

#### 1. Foundation Layer
- Built on `URLSession` for reliability and performance
- Leverages Swift 6 structured concurrency (`async`/`await`)
- Minimal external dependencies

#### 2. Core HTTP Layer
- `HTTPRequest`, `HTTPResponse`, `HTTPError` - Core data types
- `HTTPClient` protocol - Abstraction over HTTP operations
- Type-safe status codes and methods

#### 3. Middleware Pipeline Layer
- Request preprocessing
- Response postprocessing  
- Error handling and recovery
- Composable middleware chain

#### 4. Client Layer
- `NetworkClient` - Main implementation
- Configuration DSL for easy setup
- Request DSL for fluent request building

#### 5. Generated API Layer
- Swift macros for code generation
- Protocol-based API definitions
- Type-safe parameter binding

### Key Architectural Decisions

#### Sendable-First Design
All public types implement `Sendable`, ensuring thread safety across concurrent contexts.

```swift
public protocol HTTPClient: Sendable {
    func execute(_ request: HTTPRequest) async throws -> HTTPResponse
}

public struct HTTPRequest: Sendable { ... }
public struct HTTPResponse: Sendable { ... }
public struct HTTPError: Error, Sendable { ... }
```

#### Actor-Based State Management
Shared mutable state uses actors for safe concurrent access.

```swift
private actor CacheActor {
    private let cache = NSCache<NSString, CachedResponse>()
    
    func object(forKey key: NSString) -> CachedResponse? {
        cache.object(forKey: key)
    }
    
    func setObject(_ obj: CachedResponse, forKey key: NSString) {
        cache.setObject(obj, forKey: key)
    }
}
```

#### Protocol-Oriented Middleware
Middleware uses protocols enabling easy testing and composition.

```swift
public protocol HTTPRequestMiddleware: Sendable {
    func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest
}

public protocol HTTPResponseMiddleware: Sendable {
    func processResponse(_ response: HTTPResponse, for request: HTTPRequest) async throws -> HTTPResponse
}

public protocol HTTPErrorMiddleware: Sendable {
    func handleError(_ error: HTTPError, for request: HTTPRequest) async throws -> HTTPResponse
}
```

---

## Design Patterns

### 1. Builder Pattern

Multiple result builders provide fluent configuration:

```swift
// Request building
let response = try await client.execute {
    GET("/users/123")
    BearerAuth(token)
    Timeout(15.0)
}

// Client configuration  
let client = NetworkClient {
    BaseURL("https://api.example.com")
    EnableLogging()
    EnableRetry()
}

// Response processing
let user: User = try await response.process {
    StatusCodeValidator(.ok)
    JSONDecoder(User.self)
}
```

### 2. Chain of Responsibility

Middleware pipeline implements chain of responsibility:

```swift
// Request processing chain
let processedRequest = try await applyRequestMiddlewares(request)
│
├─ AuthenticationMiddleware.modifyRequest()
├─ CachingMiddleware.modifyRequest() 
└─ LoggingMiddleware.modifyRequest()

// Response processing chain  
let processedResponse = try await applyResponseMiddlewares(response)
│
├─ LoggingMiddleware.processResponse()
├─ CachingMiddleware.processResponse()
└─ MetricsMiddleware.processResponse()

// Error handling chain
let recoveredResponse = try await handleErrorWithMiddlewares(error)
│
├─ CircuitBreakerMiddleware.handleError()
├─ AuthenticationMiddleware.handleError() 
├─ RetryMiddleware.handleError()
└─ FallbackMiddleware.handleError()
```

### 3. Strategy Pattern

Multiple strategies for different concerns:

#### Authentication Strategies
```swift
public enum AuthenticationStrategy {
    case bearerToken(any BearerTokenProvider)
    case basicAuth(username: String, password: String)
    case custom(any CustomAuthProvider)
}
```

#### Retry Strategies
```swift
public enum RetryBackoffStrategy {
    case fixed
    case linear
    case exponential
    case decorrelatedJitter
    case custom((Int, TimeInterval) -> TimeInterval)
}
```

#### Caching Strategies
```swift
public enum CachingPolicy {
    case none
    case standard 
    case aggressive
    case custom(maxAge: TimeInterval, revalidate: Bool)
}
```

### 4. Factory Pattern

Factory methods for common configurations:

```swift
// Default configurations
public static func `default`() -> Configuration { ... }

// Specialized configurations
public static func aggressive() -> RetryConfiguration { ... }
public static func conservative() -> RetryConfiguration { ... }

// Test-friendly factories
public static func withMemoryStorage(ttl: TimeInterval) -> CachingMiddleware { ... }
```

### 5. Proxy Pattern

Generated API clients act as proxies to the underlying HTTP client:

```swift
@API(baseURL: "https://api.example.com")
protocol UserAPI {
    @GET("/users/{id}")
    func getUser(@Path id: String) async throws -> User
}

// Generated proxy implementation:
public struct UserAPIImplementation: UserAPI {
    private let client: any HTTPClient
    
    public func getUser(id: String) async throws -> User {
        let response = try await client.execute {
            GET("/users/\(id)")
        }
        return try response.decode(User.self)
    }
}
```

---

## Component Architecture

### Core Components

#### HTTPRequest
Immutable value type representing an HTTP request:

```swift
public struct HTTPRequest: Sendable {
    public let method: HTTPMethod
    public let url: URL
    public let headers: [String: String]
    public let body: Data?
    public let timeout: TimeInterval
}
```

**Design Decisions:**
- Immutable to prevent accidental modification
- `Sendable` for safe concurrent use
- Contains all information needed for execution

#### HTTPResponse  
Immutable value type representing an HTTP response:

```swift
public struct HTTPResponse: Sendable {
    public let request: HTTPRequest  // Reference to original request
    public let status: HTTPStatus
    public let headers: [String: String]  
    public let body: Data?
    
    // Convenience methods
    public func decode<T: Decodable>(_ type: T.Type) throws -> T
    public var isSuccess: Bool { status.isSuccess }
}
```

**Design Decisions:**
- Links back to original request for context
- Built-in JSON decoding support
- Status checking convenience methods

#### HTTPError
Comprehensive error type with context:

```swift
public struct HTTPError: Error, Sendable, LocalizedError {
    public let category: Category
    public let request: HTTPRequest?
    public let response: HTTPResponse?  
    public let underlyingError: (any Error)?
}
```

**Error Categories:**
```swift
public enum Category: Sendable, Hashable {
    case network(NetworkError)      // Connection issues
    case http(HTTPStatus)           // HTTP status errors  
    case decoding(String)           // JSON/data parsing
    case encoding(String)           // Request encoding
    case timeout                    // Request timeout
    case cancelled                  // Request cancellation
    case configuration(String)      // Setup/config errors
}
```

### Middleware Components

#### Request Middleware Architecture
```
HTTPRequest → Middleware Chain → Modified HTTPRequest
│
├─ BaseURLMiddleware      (adds base URL to relative paths)
├─ HeaderMiddleware       (adds default headers)  
├─ AuthMiddleware         (adds authorization)
├─ CacheMiddleware        (adds cache headers)
└─ LoggingMiddleware      (logs request details)
```

#### Response Middleware Architecture
```
HTTPResponse → Middleware Chain → Processed HTTPResponse  
│
├─ LoggingMiddleware      (logs response details)
├─ MetricsMiddleware      (records performance metrics)
├─ CacheMiddleware        (stores cacheable responses)
└─ ValidationMiddleware   (validates response format)
```

#### Error Middleware Architecture
```  
HTTPError → Middleware Chain → HTTPResponse or Re-thrown Error
│
├─ CircuitBreakerMiddleware (prevents cascade failures)
├─ AuthMiddleware           (handles auth errors, refreshes tokens)
├─ RetryMiddleware          (retries transient failures)
└─ FallbackMiddleware       (provides fallback responses)
```

---

## Concurrency Model

### Swift 6 Structured Concurrency

The framework is built around Swift 6's structured concurrency model:

#### Async/Await Throughout
```swift
// All operations are async  
public func execute(_ request: HTTPRequest) async throws -> HTTPResponse

// Middleware operations are async
public func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest
public func processResponse(_ response: HTTPResponse, for request: HTTPRequest) async throws -> HTTPResponse
public func handleError(_ error: HTTPError, for request: HTTPRequest) async throws -> HTTPResponse
```

#### Task Cancellation Support
```swift
public func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
    do {
        // Check for cancellation before starting
        try Task.checkCancellation()
        
        let processedRequest = try await applyRequestMiddlewares(request)
        
        // Check for cancellation before network call
        try Task.checkCancellation()
        
        let response = try await performRequest(processedRequest)
        return try await applyResponseMiddlewares(response, for: processedRequest)
    } catch is CancellationError {
        throw HTTPError(category: .cancelled, request: request)
    }
}
```

#### Actor Isolation for Shared State
```swift
// Circuit breaker state managed by actor
private actor CircuitBreakerState {
    private var state: State = .closed
    private var failureCount = 0
    private var lastFailureTime: Date?
    
    func recordSuccess() async {
        failureCount = 0
        state = .closed
    }
    
    func recordFailure() async {
        failureCount += 1
        lastFailureTime = Date()
        if failureCount >= configuration.failureThreshold {
            state = .open
        }
    }
}
```

### Concurrency Safety Guarantees

#### Sendable Compliance
All public types conform to `Sendable`:
- Value types are inherently `Sendable`
- Reference types use actor isolation or `@unchecked Sendable` with careful synchronization

#### Data Race Prevention  
- No shared mutable state without protection
- Actors used for complex shared state
- Immutable configurations passed to middleware

#### Structured Concurrency Benefits
- Automatic cancellation propagation
- Exception safety with proper cleanup
- Task hierarchy respects parent-child relationships

---

## Middleware Pipeline

### Pipeline Architecture

The middleware pipeline processes requests, responses, and errors in a structured way:

```swift
┌─────────────────────────────────────────────────────────────┐
│                    Request Flow                             │
└─────────────────────────────────────────────────────────────┘
HTTPRequest 
    │
    ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ Auth Middleware │ -> │ Cache Middleware│ -> │  Log Middleware │
└─────────────────┘    └─────────────────┘    └─────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│                   URLSession                                │
└─────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│                   Response Flow                             │
└─────────────────────────────────────────────────────────────┘
HTTPResponse
    │
    ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Log Middleware │ -> │Metrics Middleware│ -> │ Cache Middleware│
└─────────────────┘    └─────────────────┘    └─────────────────┘
    │
    ▼
Processed HTTPResponse

┌─────────────────────────────────────────────────────────────┐
│                    Error Flow                               │
└─────────────────────────────────────────────────────────────┘
HTTPError
    │
    ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│Circuit Breaker  │ -> │ Auth Middleware │ -> │ Retry Middleware│
└─────────────────┘    └─────────────────┘    └─────────────────┘
    │
    ▼
Recovered HTTPResponse or Re-thrown Error
```

### Pipeline Execution

#### Sequential Processing
```swift
private func applyRequestMiddlewares(_ request: HTTPRequest) async throws -> HTTPRequest {
    var currentRequest = request
    for middleware in requestMiddlewares {
        currentRequest = try await middleware.modifyRequest(currentRequest)
    }
    return currentRequest
}
```

#### Error Propagation  
```swift
private func handleErrorWithMiddlewares(
    _ error: HTTPError,
    for request: HTTPRequest
) async throws -> HTTPResponse {
    var currentError = error
    for middleware in errorMiddlewares {
        do {
            return try await middleware.handleError(currentError, for: request)
        } catch let newError as HTTPError {
            currentError = newError  // Continue with next middleware
        }
    }
    throw currentError  // No middleware handled the error
}
```

### Middleware Composition Strategies

#### Order Dependency Management
Certain middleware must run in specific orders:

```swift
let client = NetworkClient(
    requestMiddlewares: [
        BaseURLMiddleware(...),      // Must be first - establishes base URL
        DefaultHeadersMiddleware(...), // Early - sets default headers
        AuthenticationMiddleware(...), // After headers - may override auth headers
        CachingMiddleware(...),       // After auth - cache keys may include user context
        LoggingMiddleware(...)        // Last - logs final request state
    ],
    responseMiddlewares: [
        TimingMiddleware(...),        // First - measures total response time
        LoggingMiddleware(...),       // Early - logs response details
        CachingMiddleware(...),       // After logging - stores in cache
        ValidationMiddleware(...)     // Last - validates final response
    ],
    errorMiddlewares: [
        CircuitBreakerMiddleware(...), // First - fast-fail circuit breaking
        AuthenticationMiddleware(...), // Second - handles auth refresh
        RetryMiddleware(...),          // Third - retries after auth refresh
        FallbackMiddleware(...)        // Last - provides fallbacks
    ]
)
```

#### Conditional Middleware
Some middleware only applies under certain conditions:

```swift
// Authentication middleware checks conditions
public func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
    guard configuration.shouldAuthenticate(request) else {
        return request  // Skip authentication for this request
    }
    
    let token = try await tokenProvider.getCurrentToken()
    // ... add authorization header
}

// Caching middleware applies selectively
public func processResponse(_ response: HTTPResponse, for request: HTTPRequest) async throws -> HTTPResponse {
    guard configuration.shouldCache(request, response) else {
        return response  // Don't cache this response
    }
    
    // ... store in cache
}
```

---

## Error Handling Strategy  

### Hierarchical Error Classification

```swift
HTTPError
├── Network Errors
│   ├── noConnection        (offline, no network)
│   ├── dnsFailure         (DNS resolution failed)  
│   ├── connectionLost     (connection dropped)
│   ├── serverUnreachable  (server not responding)
│   └── sslError          (TLS/SSL issues)
│
├── HTTP Errors  
│   ├── 4xx Client Errors (bad request, unauthorized, etc.)
│   └── 5xx Server Errors (internal error, service unavailable, etc.)
│
├── Data Processing Errors
│   ├── encoding          (request encoding failed)
│   └── decoding          (response parsing failed) 
│
├── Framework Errors
│   ├── timeout           (request timeout)
│   ├── cancelled         (request cancelled)
│   └── configuration     (setup/config errors)
│
└── Custom Middleware Errors
    ├── circuitBreakerOpen  (circuit breaker preventing requests)
    ├── authenticationFailed (token refresh failed) 
    └── cacheError          (cache operation failed)
```

### Error Recovery Strategies

#### Automatic Recovery
```swift
// Auth middleware handles token refresh automatically
public func handleError(_ error: HTTPError, for request: HTTPRequest) async throws -> HTTPResponse {
    guard case .http(let status) = error.category, 
          status.rawValue == 401,
          await shouldRefreshToken(for: error) else {
        throw error
    }
    
    // Attempt token refresh
    let newToken = try await tokenProvider.refreshToken()
    
    // Retry with new token
    let updatedRequest = request.withAuthHeader(newToken)
    return try await client.execute(updatedRequest)
}
```

#### Retry with Backoff
```swift  
// Retry middleware implements exponential backoff
public func handleError(_ error: HTTPError, for request: HTTPRequest) async throws -> HTTPResponse {
    guard configuration.shouldRetry(error, 0) else {
        throw error
    }
    
    var lastError = error
    for attempt in 1...configuration.maxAttempts {
        let delay = configuration.backoffStrategy.calculateDelay(for: attempt, baseDelay: configuration.baseDelay)
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        do {
            return try await client.execute(request)
        } catch let error as HTTPError {
            lastError = error
            if !configuration.shouldRetry(error, attempt) {
                break
            }
        }
    }
    
    throw lastError
}
```

#### Circuit Breaking
```swift
// Circuit breaker prevents cascade failures
public func handleError(_ error: HTTPError, for request: HTTPRequest) async throws -> HTTPResponse {
    await circuitState.recordFailure()
    
    let currentState = await circuitState.currentState
    if currentState == .open {
        throw HTTPError(
            category: .custom(.circuitBreakerOpen),
            request: request,
            underlyingError: error
        )
    }
    
    throw error
}
```

### Error Context Preservation

Errors maintain full context for debugging:

```swift
public struct HTTPError: Error, Sendable, LocalizedError {
    public let category: Category           // Error classification
    public let request: HTTPRequest?        // Original request  
    public let response: HTTPResponse?      // Response received (if any)
    public let underlyingError: (any Error)? // System error
    
    // Rich error information
    public var errorDescription: String? { ... }
    public var failureReason: String? { ... }
    public var recoverySuggestion: String? { ... }
}
```

---

## Memory Management

### Resource Management Strategies

#### Bounded Collections
All caches and collections have size limits:

```swift
// Cache with memory bounds
private actor CacheActor {
    private let cache = NSCache<NSString, CachedResponse>()
    
    init(maxSize: Int) {
        cache.totalCostLimit = maxSize
        cache.delegate = self // Automatic cleanup
    }
}

// Metrics collection with bounds
public actor MemoryMetricsCollector: MetricsCollector {
    private var metrics: [RequestMetrics] = []
    private let maxCount: Int
    
    init(maxMetricsCount: Int = 1000) {
        self.maxCount = maxMetricsCount
    }
    
    public func recordMetrics(_ newMetrics: RequestMetrics) async {
        metrics.append(newMetrics)
        if metrics.count > maxCount {
            metrics.removeFirst() // FIFO cleanup
        }
    }
}
```

#### Automatic Cleanup
```swift
// TTL-based cache cleanup
public func removeExpired() async {
    let now = Date()
    entries = entries.filter { entry in
        now.timeIntervalSince(entry.cachedAt) < entry.ttl
    }
}

// Periodic cleanup tasks
private func scheduleCleanup() {
    Task.detached { [weak self] in
        while !Task.isCancelled {
            await self?.removeExpired()
            try? await Task.sleep(nanoseconds: 300_000_000_000) // 5 minutes
        }
    }
}
```

#### Weak References
Avoid retain cycles in middleware:

```swift  
// Middleware doesn't strongly retain client
public struct RetryMiddleware: HTTPErrorMiddleware {
    private weak var client: (any HTTPClient)?
    
    public func handleError(_ error: HTTPError, for request: HTTPRequest) async throws -> HTTPResponse {
        guard let client = client else {
            throw error // Client deallocated
        }
        
        return try await performRetry(using: client, for: request, error: error)
    }
}
```

### Swift 6 Memory Safety

#### Sendable Compliance
Prevents data races at compile time:

```swift
// All public types are Sendable
public struct HTTPRequest: Sendable { ... }
public struct HTTPResponse: Sendable { ... }
public struct HTTPError: Error, Sendable { ... }

// Protocols require Sendable conformance
public protocol HTTPClient: Sendable {
    func execute(_ request: HTTPRequest) async throws -> HTTPResponse
}
```

#### Actor Isolation
Shared mutable state protected by actors:

```swift
private actor CircuitBreakerState: Sendable {
    private var state: State = .closed
    private var failureCount = 0
    
    // All mutations are serialized through the actor
    func recordFailure() async {
        failureCount += 1
        if failureCount >= threshold {
            state = .open
        }
    }
}
```

#### Value Semantics
Immutable data structures prevent accidental sharing:

```swift
// Configurations are immutable value types
public struct Configuration: Sendable {
    public let maxAttempts: Int
    public let baseDelay: TimeInterval
    public let shouldRetry: (HTTPError, Int) -> Bool
    
    // No mutation methods - create new instances for changes
}
```

---

## Testing Architecture

### Testable Design Principles

#### Protocol-Based Architecture
All major components use protocols enabling easy mocking:

```swift
// HTTPClient protocol allows mock implementations
public protocol HTTPClient: Sendable {
    func execute(_ request: HTTPRequest) async throws -> HTTPResponse
}

// Test implementation
public struct MockHTTPClient: HTTPClient {
    private let responseHandler: (HTTPRequest) -> HTTPResponse
    
    public func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        return responseHandler(request)
    }
}
```

#### Dependency Injection
Middleware and clients accept dependencies through initializers:

```swift
// AuthenticationMiddleware accepts token provider
public struct AuthenticationMiddleware {
    private let tokenProvider: any TokenProvider
    private let client: any HTTPClient
    
    public init(tokenProvider: any TokenProvider, client: any HTTPClient) {
        self.tokenProvider = tokenProvider  
        self.client = client
    }
}

// Test with mock dependencies
let mockTokenProvider = MockTokenProvider()
let mockClient = MockHTTPClient()
let middleware = AuthenticationMiddleware(
    tokenProvider: mockTokenProvider,
    client: mockClient
)
```

### Testing Utilities

#### Mock Implementations
The framework provides mock implementations for testing:

```swift
public struct MockHTTPClient: HTTPClient {
    private let responseHandler: (HTTPRequest) async throws -> HTTPResponse
    
    public init(responseHandler: @escaping (HTTPRequest) async throws -> HTTPResponse) {
        self.responseHandler = responseHandler
    }
    
    public func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        return try await responseHandler(request)
    }
}

// Usage in tests
let client = MockHTTPClient { request in
    HTTPResponse(
        request: request,
        status: .ok,
        headers: ["Content-Type": "application/json"],
        body: #"{"id": "123", "name": "Test"}"#.data(using: .utf8)
    )
}
```

#### Request Verification
```swift
public struct RequestCapturingClient: HTTPClient {
    private let responses: [HTTPResponse]
    private let requestHandler: (HTTPRequest) -> Void
    
    public func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        requestHandler(request) // Capture for verification
        return responses.removeFirst()
    }
}

// Test usage  
var capturedRequests: [HTTPRequest] = []
let client = RequestCapturingClient { request in
    capturedRequests.append(request)
}

// Make requests and verify
try await client.execute(someRequest)
XCTAssertEqual(capturedRequests.count, 1)
XCTAssertEqual(capturedRequests[0].url.path, "/expected/path")
```

### Swift Testing Integration

The framework integrates with Swift's new Testing framework:

```swift
import Testing
import Networking

@Test("NetworkClient executes basic requests correctly")
func basicRequestExecution() async throws {
    let client = MockHTTPClient { request in
        #expect(request.method == .get)
        #expect(request.url.path == "/test")
        
        return HTTPResponse(
            request: request,
            status: .ok,
            body: #"{"success": true}"#.data(using: .utf8)
        )
    }
    
    let response = try await client.execute {
        GET("/test")
    }
    
    #expect(response.status == .ok)
    #expect(response.isSuccess)
}

@Test("Middleware chain processes requests correctly")
func middlewareChainProcessing() async throws {
    var middlewareCallOrder: [String] = []
    
    let middleware1 = TestRequestMiddleware("middleware1") { request in
        middlewareCallOrder.append("middleware1")
        return request
    }
    
    let middleware2 = TestRequestMiddleware("middleware2") { request in
        middlewareCallOrder.append("middleware2")
        return request
    }
    
    let client = NetworkClient(
        requestMiddlewares: [middleware1, middleware2]
    )
    
    _ = try await client.execute(testRequest)
    
    #expect(middlewareCallOrder == ["middleware1", "middleware2"])
}
```

---

## Swift 6 Compliance

### Concurrency Compliance

#### Full async/await Support
```swift
// All operations are properly async
public func execute(_ request: HTTPRequest) async throws -> HTTPResponse
public func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest  
public func processResponse(_ response: HTTPResponse, for request: HTTPRequest) async throws -> HTTPResponse
```

#### Structured Concurrency
```swift
// Task groups for concurrent operations
public func executeMultiple(_ requests: [HTTPRequest]) async throws -> [HTTPResponse] {
    return try await withThrowingTaskGroup(of: HTTPResponse.self) { group in
        for request in requests {
            group.addTask {
                try await self.execute(request)
            }
        }
        
        var responses: [HTTPResponse] = []
        for try await response in group {
            responses.append(response)
        }
        return responses
    }
}
```

#### Cancellation Support  
```swift
// Proper cancellation checking
public func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
    try Task.checkCancellation()
    
    let processedRequest = try await applyRequestMiddlewares(request)
    
    try Task.checkCancellation()
    
    return try await performNetworkRequest(processedRequest)
}
```

### Sendable Compliance

#### Value Types
```swift
// All data models are Sendable value types
public struct HTTPRequest: Sendable {
    public let method: HTTPMethod
    public let url: URL
    public let headers: [String: String]  // Dictionary is Sendable
    public let body: Data?                // Data is Sendable
    public let timeout: TimeInterval      // TimeInterval is Sendable
}
```

#### Reference Types with Actor Isolation
```swift
// Shared mutable state uses actors
private actor CacheState {
    private var entries: [String: CacheEntry] = [:]
    
    func get(_ key: String) -> CacheEntry? {
        entries[key]
    }
    
    func set(_ key: String, entry: CacheEntry) {
        entries[key] = entry
    }
}
```

#### Protocol Requirements
```swift
// All protocols require Sendable conformance
public protocol HTTPClient: Sendable {
    func execute(_ request: HTTPRequest) async throws -> HTTPResponse
}

public protocol HTTPRequestMiddleware: Sendable {
    func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest
}
```

### Data Race Prevention

#### Immutable Configurations
```swift
// Configuration objects are immutable
public struct RetryConfiguration: Sendable {
    public let maxAttempts: Int
    public let baseDelay: TimeInterval
    public let backoffStrategy: RetryBackoffStrategy
    
    // No mutation methods - create new instances for changes
    public func withMaxAttempts(_ attempts: Int) -> RetryConfiguration {
        RetryConfiguration(
            maxAttempts: attempts,
            baseDelay: baseDelay,
            backoffStrategy: backoffStrategy
        )
    }
}
```

#### Thread-Safe Shared State
```swift  
// Complex shared state uses actors
private actor JitterState {
    private var lastDelay: TimeInterval = 0
    
    func calculateDecorrelatedDelay(baseDelay: TimeInterval, maxDelay: TimeInterval) -> TimeInterval {
        let random = TimeInterval.random(in: baseDelay...(lastDelay * 3))
        let bounded = min(random, maxDelay)
        lastDelay = bounded
        return bounded
    }
}
```

#### Safe Concurrent Collections
```swift
// Collections that need concurrent access use actors
public actor SafeMetricsCollector: MetricsCollector {
    private var metrics: [RequestMetrics] = []
    
    public func recordMetrics(_ newMetrics: RequestMetrics) async {
        metrics.append(newMetrics)
    }
    
    public func getAllMetrics() async -> [RequestMetrics] {
        metrics  // Safe to return as RequestMetrics is Sendable
    }
}
```

This architecture provides a solid foundation for building reliable, performant, and maintainable networking code in Swift 6 applications.