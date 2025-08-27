# Swift 6 Features in ModernNetworking

## Table of Contents

1. [Overview](#overview)
2. [Sendable Conformance](#sendable-conformance)
3. [Actor Isolation](#actor-isolation)
4. [Structured Concurrency](#structured-concurrency)
5. [Data Race Safety](#data-race-safety)
6. [Result Builders](#result-builders)
7. [Swift Macros](#swift-macros)
8. [Async/Await Patterns](#asyncawait-patterns)
9. [Error Handling](#error-handling)
10. [Migration Benefits](#migration-benefits)

---

## Overview

ModernNetworking is built from the ground up to leverage Swift 6's advanced concurrency and safety features. This document details how the framework uses these features to provide a safe, performant, and developer-friendly networking experience.

### Swift 6 Compliance Highlights

✅ **Full Sendable conformance** - All public types are thread-safe by design  
✅ **Actor-based state management** - Shared mutable state protected by actors  
✅ **Structured concurrency support** - Proper task cancellation and hierarchy  
✅ **Data race prevention** - Compile-time safety guarantees  
✅ **Modern result builders** - Type-safe DSL construction  
✅ **Swift macros integration** - Generated API clients with full type safety

---

## Sendable Conformance

### Core Types Are Sendable

All fundamental types in ModernNetworking conform to `Sendable`, ensuring thread safety:

```swift
// Core HTTP types
public struct HTTPRequest: Sendable {
    public let method: HTTPMethod        // Sendable enum
    public let url: URL                  // URL is Sendable
    public let headers: [String: String] // Dictionary<String, String> is Sendable
    public let body: Data?               // Data is Sendable
    public let timeout: TimeInterval     // TimeInterval is Sendable
}

public struct HTTPResponse: Sendable {
    public let request: HTTPRequest      // HTTPRequest is Sendable
    public let status: HTTPStatus        // HTTPStatus is Sendable
    public let headers: [String: String] // Dictionary<String, String> is Sendable
    public let body: Data?               // Data is Sendable
}

public struct HTTPError: Error, Sendable, LocalizedError {
    public let category: Category        // Category is Sendable
    public let request: HTTPRequest?     // HTTPRequest is Sendable
    public let response: HTTPResponse?   // HTTPResponse is Sendable
    public let underlyingError: (any Error)? // any Error is Sendable in Swift 6
}
```

### Protocol Requirements

All protocols require `Sendable` conformance:

```swift
public protocol HTTPClient: Sendable {
    func execute(_ request: HTTPRequest) async throws -> HTTPResponse
}

public protocol HTTPRequestMiddleware: Sendable {
    func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest
}

public protocol HTTPResponseMiddleware: Sendable {
    func processResponse(
        _ response: HTTPResponse,
        for request: HTTPRequest
    ) async throws -> HTTPResponse
}

public protocol HTTPErrorMiddleware: Sendable {
    func handleError(
        _ error: HTTPError,
        for request: HTTPRequest
    ) async throws -> HTTPResponse
}
```

### Configuration Types

Configuration objects are immutable value types:

```swift
public struct RetryConfiguration: Sendable {
    public let maxAttempts: Int
    public let baseDelay: TimeInterval
    public let backoffMultiplier: Double
    public let jitterStrategy: JitterStrategy
    public let shouldRetry: @Sendable (HTTPError, Int) -> Bool
    
    // Note: Closures must be marked @Sendable
    public init(
        maxAttempts: Int = 3,
        baseDelay: TimeInterval = 1.0,
        backoffMultiplier: Double = 2.0,
        jitterStrategy: JitterStrategy = .equal,
        shouldRetry: @Sendable @escaping (HTTPError, Int) -> Bool = defaultRetryCondition
    ) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.backoffMultiplier = backoffMultiplier
        self.jitterStrategy = jitterStrategy
        self.shouldRetry = shouldRetry
    }
}
```

### Request Components

All request builder components are `Sendable`:

```swift
public struct GET: RequestComponent, Sendable {
    private let path: String
    
    public init(_ path: String) {
        self.path = path
    }
    
    public func apply(to request: inout RequestBuilder.PartialRequest) throws {
        request.method = .get
        if let existingURL = request.url {
            request.url = existingURL.appendingPathComponent(path)
        } else {
            request.url = URL(string: path)
        }
    }
}

public struct BearerAuth: RequestComponent, Sendable {
    private let token: String
    
    public init(_ token: String) {
        self.token = token
    }
    
    public func apply(to request: inout RequestBuilder.PartialRequest) throws {
        request.headers["Authorization"] = "Bearer \(token)"
    }
}
```

---

## Actor Isolation

### Shared Mutable State Protection

Complex shared state uses actors for safe concurrent access:

```swift
/// Circuit breaker state managed by actor
private actor CircuitBreakerState {
    private var state: CircuitState = .closed
    private var failureCount: Int = 0
    private var lastFailureTime: Date?
    private var successCount: Int = 0
    
    enum CircuitState: Sendable {
        case closed, open, halfOpen
    }
    
    func getCurrentState() -> CircuitState {
        state
    }
    
    func recordFailure() {
        failureCount += 1
        lastFailureTime = Date()
        
        if failureCount >= configuration.failureThreshold {
            state = .open
        }
    }
    
    func recordSuccess() {
        successCount += 1
        
        if state == .halfOpen && successCount >= configuration.successThreshold {
            state = .closed
            failureCount = 0
            successCount = 0
        }
    }
    
    func shouldAllowRequest() -> Bool {
        switch state {
        case .closed:
            return true
        case .open:
            guard let lastFailure = lastFailureTime else { return false }
            return Date().timeIntervalSince(lastFailure) > configuration.recoveryTimeout
        case .halfOpen:
            return true // Allow limited requests in half-open state
        }
    }
}
```

### Cache Management with Actors

```swift
/// Thread-safe cache implementation using actors
private actor CacheActor {
    private var entries: [String: CacheEntry] = [:]
    private let maxSize: Int
    
    init(maxSize: Int) {
        self.maxSize = maxSize
    }
    
    func get(key: String) -> CacheEntry? {
        // Automatic cleanup of expired entries
        cleanExpiredEntries()
        return entries[key]
    }
    
    func set(key: String, entry: CacheEntry) {
        cleanExpiredEntries()
        
        // Evict oldest entries if at capacity
        if entries.count >= maxSize {
            evictOldestEntries(count: entries.count - maxSize + 1)
        }
        
        entries[key] = entry
    }
    
    func remove(key: String) {
        entries.removeValue(forKey: key)
    }
    
    func clear() {
        entries.removeAll()
    }
    
    private func cleanExpiredEntries() {
        let now = Date()
        entries = entries.filter { _, entry in
            now.timeIntervalSince(entry.createdAt) < entry.ttl
        }
    }
    
    private func evictOldestEntries(count: Int) {
        let sortedKeys = entries.keys.sorted { key1, key2 in
            let entry1 = entries[key1]!
            let entry2 = entries[key2]!
            return entry1.createdAt < entry2.createdAt
        }
        
        for i in 0..<min(count, sortedKeys.count) {
            entries.removeValue(forKey: sortedKeys[i])
        }
    }
}

struct CacheEntry: Sendable {
    let data: Data
    let headers: [String: String]
    let status: HTTPStatus
    let createdAt: Date
    let ttl: TimeInterval
}
```

### Metrics Collection with Actors

```swift
/// Thread-safe metrics collection
public actor MetricsCollector {
    private var metrics: [RequestMetrics] = []
    private let maxCount: Int
    
    public init(maxCount: Int = 1000) {
        self.maxCount = maxCount
    }
    
    public func record(_ metric: RequestMetrics) {
        metrics.append(metric)
        
        // Keep only the most recent metrics
        if metrics.count > maxCount {
            metrics.removeFirst(metrics.count - maxCount)
        }
    }
    
    public func getMetrics() -> [RequestMetrics] {
        metrics
    }
    
    public func getAverageResponseTime() -> TimeInterval {
        guard !metrics.isEmpty else { return 0 }
        let total = metrics.reduce(0) { $0 + $1.responseTime }
        return total / Double(metrics.count)
    }
    
    public func getSuccessRate() -> Double {
        guard !metrics.isEmpty else { return 0 }
        let successCount = metrics.filter { $0.success }.count
        return Double(successCount) / Double(metrics.count)
    }
    
    public func clear() {
        metrics.removeAll()
    }
}

public struct RequestMetrics: Sendable {
    public let url: URL
    public let method: HTTPMethod
    public let statusCode: Int
    public let responseTime: TimeInterval
    public let requestSize: Int
    public let responseSize: Int
    public let success: Bool
    public let timestamp: Date
    
    public init(
        url: URL,
        method: HTTPMethod,
        statusCode: Int,
        responseTime: TimeInterval,
        requestSize: Int,
        responseSize: Int,
        success: Bool,
        timestamp: Date = Date()
    ) {
        self.url = url
        self.method = method
        self.statusCode = statusCode
        self.responseTime = responseTime
        self.requestSize = requestSize
        self.responseSize = responseSize
        self.success = success
        self.timestamp = timestamp
    }
}
```

---

## Structured Concurrency

### Task Group Usage

Structured concurrency for batch operations:

```swift
extension NetworkClient {
    /// Execute multiple requests concurrently with structured concurrency
    public func executeAll<T>(_ requests: [(HTTPRequest, T.Type)]) async throws -> [T] where T: Decodable {
        return try await withThrowingTaskGroup(of: (Int, T).self) { group in
            // Add tasks for each request
            for (index, (request, type)) in requests.enumerated() {
                group.addTask { [self] in
                    let response = try await self.execute(request)
                    let decoded = try response.decode(type)
                    return (index, decoded)
                }
            }
            
            // Collect results in order
            var results: [T?] = Array(repeating: nil, count: requests.count)
            for try await (index, result) in group {
                results[index] = result
            }
            
            return results.compactMap { $0 }
        }
    }
    
    /// Execute requests with rate limiting
    public func executeWithRateLimit<T>(
        _ requests: [HTTPRequest],
        responseType: T.Type,
        maxConcurrency: Int = 5
    ) async throws -> [Result<T, Error>] where T: Decodable {
        
        let semaphore = AsyncSemaphore(value: maxConcurrency)
        
        return try await withThrowingTaskGroup(of: (Int, Result<T, Error>).self) { group in
            for (index, request) in requests.enumerated() {
                group.addTask { [self] in
                    await semaphore.wait()
                    defer { semaphore.signal() }
                    
                    do {
                        let response = try await self.execute(request)
                        let decoded = try response.decode(responseType)
                        return (index, .success(decoded))
                    } catch {
                        return (index, .failure(error))
                    }
                }
            }
            
            var results: [Result<T, Error>] = Array(repeating: .failure(ConcurrencyError.notProcessed), count: requests.count)
            for try await (index, result) in group {
                results[index] = result
            }
            
            return results
        }
    }
}

/// Simple semaphore implementation for concurrency control
public actor AsyncSemaphore {
    private var count: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []
    
    public init(value: Int) {
        self.count = value
    }
    
    public func wait() async {
        if count > 0 {
            count -= 1
        } else {
            await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }
    }
    
    public func signal() {
        if let waiter = waiters.first {
            waiters.removeFirst()
            waiter.resume()
        } else {
            count += 1
        }
    }
}
```

### Cancellation Support

Proper cancellation handling throughout the framework:

```swift
extension NetworkClient {
    public func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        // Check for cancellation before starting
        try Task.checkCancellation()
        
        do {
            // Apply request middlewares
            let processedRequest = try await applyRequestMiddlewares(request)
            
            // Check for cancellation after middleware processing
            try Task.checkCancellation()
            
            // Execute the request
            let response = try await performRequest(processedRequest)
            
            // Check for cancellation before response processing
            try Task.checkCancellation()
            
            // Apply response middlewares
            return try await applyResponseMiddlewares(response, for: processedRequest)
            
        } catch is CancellationError {
            // Convert to HTTPError for consistent error handling
            throw HTTPError(category: .cancelled, request: request)
        } catch let error as HTTPError {
            // Try to handle error with middlewares
            return try await handleErrorWithMiddlewares(error, for: request)
        } catch {
            // Convert other errors to HTTPError
            let httpError = HTTPError(
                category: .network(.serverUnreachable),
                request: request,
                underlyingError: error
            )
            return try await handleErrorWithMiddlewares(httpError, for: request)
        }
    }
    
    private func performRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
        // Use URLSession's built-in cancellation support
        let (data, response) = try await session.data(for: buildURLRequest(from: request))
        
        // URLSession automatically handles Task cancellation
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPError(category: .network(.serverUnreachable), request: request)
        }
        
        return HTTPResponse(
            request: request,
            httpURLResponse: httpResponse,
            body: data
        )
    }
}
```

### Child Task Management

```swift
/// Long-running network monitor with proper task management
public actor NetworkMonitor {
    private var monitoringTask: Task<Void, Never>?
    private var isMonitoring = false
    
    public func startMonitoring() async {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        
        monitoringTask = Task {
            await withTaskGroup(of: Void.self) { group in
                // Monitor connection status
                group.addTask {
                    await self.monitorConnectionStatus()
                }
                
                // Monitor performance metrics
                group.addTask {
                    await self.monitorPerformanceMetrics()
                }
                
                // Monitor error rates
                group.addTask {
                    await self.monitorErrorRates()
                }
                
                // Wait for all monitoring tasks
                await group.waitForAll()
            }
        }
    }
    
    public func stopMonitoring() async {
        isMonitoring = false
        monitoringTask?.cancel()
        monitoringTask = nil
    }
    
    private func monitorConnectionStatus() async {
        while !Task.isCancelled && isMonitoring {
            // Check connection status
            let isConnected = await checkNetworkConnectivity()
            
            if isConnected != currentConnectionStatus {
                currentConnectionStatus = isConnected
                await notifyConnectionChange(isConnected)
            }
            
            // Wait before next check, with cancellation support
            do {
                try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            } catch is CancellationError {
                break
            } catch {
                // Handle other errors
                continue
            }
        }
    }
}
```

---

## Data Race Safety

### Immutable Configuration

All configuration objects are immutable, preventing data races:

```swift
public struct NetworkClientConfiguration: Sendable {
    public let baseURL: URL?
    public let defaultHeaders: [String: String]
    public let requestTimeout: TimeInterval
    public let retryConfiguration: RetryConfiguration?
    public let cachingConfiguration: CachingConfiguration?
    public let authenticationConfiguration: AuthenticationConfiguration?
    
    // All properties are let constants
    // No mutation methods
    
    public init(
        baseURL: URL? = nil,
        defaultHeaders: [String: String] = [:],
        requestTimeout: TimeInterval = 30.0,
        retryConfiguration: RetryConfiguration? = nil,
        cachingConfiguration: CachingConfiguration? = nil,
        authenticationConfiguration: AuthenticationConfiguration? = nil
    ) {
        self.baseURL = baseURL
        self.defaultHeaders = defaultHeaders
        self.requestTimeout = requestTimeout
        self.retryConfiguration = retryConfiguration
        self.cachingConfiguration = cachingConfiguration
        self.authenticationConfiguration = authenticationConfiguration
    }
    
    // Create new instance with changes (copy-on-write pattern)
    public func with(
        baseURL: URL? = nil,
        defaultHeaders: [String: String]? = nil,
        requestTimeout: TimeInterval? = nil
    ) -> NetworkClientConfiguration {
        return NetworkClientConfiguration(
            baseURL: baseURL ?? self.baseURL,
            defaultHeaders: defaultHeaders ?? self.defaultHeaders,
            requestTimeout: requestTimeout ?? self.requestTimeout,
            retryConfiguration: self.retryConfiguration,
            cachingConfiguration: self.cachingConfiguration,
            authenticationConfiguration: self.authenticationConfiguration
        )
    }
}
```

### Thread-Safe Collections

Use of thread-safe collections and patterns:

```swift
/// Thread-safe request queue
public actor RequestQueue {
    private var pendingRequests: [QueuedRequest] = []
    private var isProcessing = false
    private let maxConcurrency: Int
    
    public init(maxConcurrency: Int = 5) {
        self.maxConcurrency = maxConcurrency
    }
    
    public func enqueue(_ request: HTTPRequest, priority: RequestPriority = .normal) async -> HTTPResponse {
        return await withCheckedContinuation { continuation in
            let queuedRequest = QueuedRequest(
                request: request,
                priority: priority,
                continuation: continuation
            )
            
            pendingRequests.append(queuedRequest)
            pendingRequests.sort { $0.priority.rawValue > $1.priority.rawValue }
            
            if !isProcessing {
                Task {
                    await processQueue()
                }
            }
        }
    }
    
    private func processQueue() async {
        guard !isProcessing, !pendingRequests.isEmpty else { return }
        
        isProcessing = true
        defer { isProcessing = false }
        
        await withTaskGroup(of: Void.self) { group in
            var activeCount = 0
            
            while !pendingRequests.isEmpty && activeCount < maxConcurrency {
                let queuedRequest = pendingRequests.removeFirst()
                activeCount += 1
                
                group.addTask {
                    do {
                        let response = try await self.executeRequest(queuedRequest.request)
                        queuedRequest.continuation.resume(returning: response)
                    } catch {
                        // Convert error to HTTPError and resume with error
                        let httpError = error as? HTTPError ?? HTTPError(
                            category: .network(.serverUnreachable),
                            request: queuedRequest.request,
                            underlyingError: error
                        )
                        queuedRequest.continuation.resume(throwing: httpError)
                    }
                }
            }
        }
        
        // Continue processing if more requests were added
        if !pendingRequests.isEmpty {
            await processQueue()
        }
    }
}

struct QueuedRequest: Sendable {
    let request: HTTPRequest
    let priority: RequestPriority
    let continuation: CheckedContinuation<HTTPResponse, Error>
}

enum RequestPriority: Int, Sendable, Comparable {
    case low = 1
    case normal = 5
    case high = 10
    case critical = 20
    
    static func < (lhs: RequestPriority, rhs: RequestPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
```

### Atomic Operations

Using actors for atomic operations:

```swift
/// Atomic counter for tracking requests
public actor RequestCounter {
    private var count: Int = 0
    private var successCount: Int = 0
    private var errorCount: Int = 0
    
    public func increment() -> Int {
        count += 1
        return count
    }
    
    public func recordSuccess() {
        successCount += 1
    }
    
    public func recordError() {
        errorCount += 1
    }
    
    public func getStats() -> (total: Int, success: Int, errors: Int) {
        return (count, successCount, errorCount)
    }
    
    public func reset() {
        count = 0
        successCount = 0
        errorCount = 0
    }
}
```

---

## Result Builders

### Request Builder Implementation

The framework provides a sophisticated result builder for constructing requests:

```swift
@resultBuilder
public struct RequestBuilder {
    public struct PartialRequest: Sendable {
        public var method: HTTPMethod = .get
        public var url: URL?
        public var headers: [String: String] = [:]
        public var body: Data?
        public var timeout: TimeInterval = 30.0
        
        public init() {}
    }
    
    // Build a single component
    public static func buildBlock(_ component: any RequestComponent) -> [any RequestComponent] {
        [component]
    }
    
    // Build multiple components
    public static func buildBlock(_ components: any RequestComponent...) -> [any RequestComponent] {
        components
    }
    
    // Support for conditional statements
    public static func buildOptional(_ component: [any RequestComponent]?) -> [any RequestComponent] {
        component ?? []
    }
    
    // Support for if-else statements
    public static func buildEither(first component: [any RequestComponent]) -> [any RequestComponent] {
        component
    }
    
    public static func buildEither(second component: [any RequestComponent]) -> [any RequestComponent] {
        component
    }
    
    // Support for loops
    public static func buildArray(_ components: [[any RequestComponent]]) -> [any RequestComponent] {
        components.flatMap { $0 }
    }
    
    // Support for availability checks
    public static func buildLimitedAvailability(_ component: [any RequestComponent]) -> [any RequestComponent] {
        component
    }
    
    // Support for partial results (Swift 5.8+)
    public static func buildPartialBlock(first: any RequestComponent) -> [any RequestComponent] {
        [first]
    }
    
    public static func buildPartialBlock(accumulated: [any RequestComponent], next: any RequestComponent) -> [any RequestComponent] {
        accumulated + [next]
    }
    
    /// Build the final request from components
    public static func build(@RequestBuilder _ content: () -> [any RequestComponent]) throws -> HTTPRequest {
        var partial = PartialRequest()
        let components = content()
        
        for component in components {
            try component.apply(to: &partial)
        }
        
        guard let url = partial.url else {
            throw HTTPError(category: .configuration("URL is required"))
        }
        
        return HTTPRequest(
            method: partial.method,
            url: url,
            headers: partial.headers,
            body: partial.body,
            timeout: partial.timeout
        )
    }
}
```

### Network Client Builder

Configuration DSL using result builders:

```swift
@resultBuilder
public struct NetworkClientBuilder {
    public struct Configuration: Sendable {
        public var baseURL: URL?
        public var session: URLSession = .shared
        public var defaultHeaders: [String: String] = [:]
        public var requestMiddlewares: [any HTTPRequestMiddleware] = []
        public var responseMiddlewares: [any HTTPResponseMiddleware] = []
        public var errorMiddlewares: [any HTTPErrorMiddleware] = []
        public var authenticationConfiguration: AuthenticationConfiguration?
        public var retryConfiguration: RetryConfiguration?
        public var cachingConfiguration: CachingConfiguration?
        
        public init() {}
    }
    
    public static func buildBlock(_ components: any ConfigurationComponent...) -> [any ConfigurationComponent] {
        components
    }
    
    public static func buildOptional(_ component: [any ConfigurationComponent]?) -> [any ConfigurationComponent] {
        component ?? []
    }
    
    public static func buildEither(first component: [any ConfigurationComponent]) -> [any ConfigurationComponent] {
        component
    }
    
    public static func buildEither(second component: [any ConfigurationComponent]) -> [any ConfigurationComponent] {
        component
    }
    
    public static func buildArray(_ components: [[any ConfigurationComponent]]) -> [any ConfigurationComponent] {
        components.flatMap { $0 }
    }
}

// Usage example with all Swift 6 features
let client = NetworkClient {
    BaseURL("https://api.example.com")
    DefaultHeader("User-Agent", "MyApp/1.0")
    DefaultTimeout(30.0)
    
    // Conditional configuration
    if isDebugMode {
        EnableLogging(LoggingMiddleware.Configuration(
            logLevel: .debug,
            logHeaders: true,
            logBody: true
        ))
    }
    
    // Authentication block
    Authentication {
        BearerToken(userToken)
        RefreshStrategy.automatic()
        AuthenticateWhen.always()
    }
    
    // Retry configuration
    Retry {
        MaxAttempts(3)
        BackoffStrategy.exponential()
        InitialDelay(1.0)
        MaxDelay(30.0)
        RetryWhen { error, attempt in
            // @Sendable closure
            switch error.category {
            case .network: return true
            case .http(let status) where status.rawValue >= 500: return attempt <= 2
            default: return false
            }
        }
    }
    
    // Loop-based configuration
    for header in customHeaders {
        DefaultHeader(header.key, header.value)
    }
}
```

---

## Swift Macros

### API Client Generation

The framework provides comprehensive macro support for generating type-safe API clients:

```swift
// Macro declarations with Swift 6 compliance
@attached(extension)
public macro API(baseURL: String) = #externalMacro(module: "ModernNetworkingMacros", type: "APIMacro")

@attached(peer)
public macro GET(_ path: String) = #externalMacro(module: "ModernNetworkingMacros", type: "GETMacro")

@attached(peer)
public macro POST(_ path: String) = #externalMacro(module: "ModernNetworkingMacros", type: "POSTMacro")

@attached(peer)
public macro Path(_ name: String? = nil) = #externalMacro(module: "ModernNetworkingMacros", type: "PathMacro")

@attached(peer)
public macro Body() = #externalMacro(module: "ModernNetworkingMacros", type: "BodyMacro")

@attached(peer)
public macro Query(_ name: String? = nil) = #externalMacro(module: "ModernNetworkingMacros", type: "QueryMacro")

// Usage - generates fully Swift 6 compliant code
@API(baseURL: "https://api.example.com")
protocol UserAPI {
    @GET("/users/{id}")
    func getUser(@Path id: String) async throws -> User
    
    @POST("/users")
    func createUser(@Body user: CreateUserRequest) async throws -> User
    
    @GET("/users")
    func searchUsers(
        @Query name: String?,
        @Query("max_results") limit: Int = 20
    ) async throws -> [User]
}

// Generated implementation (conceptual - actual generation by macro)
extension UserAPI {
    // Generated implementation is fully Sendable compliant
}

public struct UserAPIImplementation: UserAPI, Sendable {
    private let client: any HTTPClient
    
    public init(client: any HTTPClient = NetworkClient()) {
        self.client = client
    }
    
    public func getUser(id: String) async throws -> User {
        let response = try await client.execute {
            GET("/users/\(id)")
        }
        
        return try response.decode(User.self)
    }
    
    public func createUser(user: CreateUserRequest) async throws -> User {
        let response = try await client.execute {
            POST("/users")
            JSONBody(user)
            Header("Content-Type", "application/json")
        }
        
        return try response.decode(User.self)
    }
    
    public func searchUsers(name: String?, limit: Int = 20) async throws -> [User] {
        let response = try await client.execute {
            GET("/users")
            
            if let name = name {
                QueryParam("name", name)
            }
            
            QueryParam("max_results", "\(limit)")
        }
        
        return try response.decode([User].self)
    }
}
```

### Macro Implementation

Macro implementations use Swift 6 syntax features:

```swift
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct APIMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        
        guard let protocolDecl = declaration.as(ProtocolDeclSyntax.self) else {
            throw MacroError.notAProtocol
        }
        
        let baseURL = try extractBaseURL(from: node)
        let protocolName = protocolDecl.name.text
        let implementationName = "\(protocolName)Implementation"
        
        let extension = try ExtensionDeclSyntax(
            "extension \(raw: protocolName)") {
                // Generate factory method
                """
                public static func create(
                    client: any HTTPClient = NetworkClient {
                        BaseURL("\(raw: baseURL)")
                        EnableLogging()
                    }
                ) -> \(raw: implementationName) {
                    return \(raw: implementationName)(client: client)
                }
                """
            }
        
        let implementation = try StructDeclSyntax(
            "public struct \(raw: implementationName): \(raw: protocolName), Sendable") {
                
                // Client property
                "private let client: any HTTPClient"
                
                // Initializer
                """
                public init(client: any HTTPClient) {
                    self.client = client
                }
                """
                
                // Generate method implementations
                for member in protocolDecl.memberBlock.members {
                    if let function = member.decl.as(FunctionDeclSyntax.self) {
                        try generateMethodImplementation(function)
                    }
                }
            }
        
        return [extension, implementation.as(ExtensionDeclSyntax.self)!]
    }
}
```

---

## Async/Await Patterns

### Natural Async Patterns

The framework is designed around natural async/await patterns:

```swift
// Simple async request
let user: User = try await client.execute {
    GET("/users/123")
    BearerAuth(token)
}.decode(User.self)

// Concurrent requests
async let user = client.execute { GET("/user") }
async let posts = client.execute { GET("/user/posts") }
async let followers = client.execute { GET("/user/followers") }

let (userResponse, postsResponse, followersResponse) = try await (user, posts, followers)

// Stream processing
for try await chunk in responseStream {
    await processChunk(chunk)
}

// Error handling with async
do {
    let result = try await client.execute {
        POST("/data")
        JSONBody(complexData)
    }
    
    await processResult(result)
} catch let error as HTTPError {
    await handleError(error)
}
```

### Middleware Async Patterns

All middleware operations are naturally async:

```swift
public struct AsyncAuthenticationMiddleware: HTTPRequestMiddleware {
    private let tokenProvider: any AsyncTokenProvider
    
    public func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
        // Async token fetching
        let token = try await tokenProvider.getCurrentToken()
        
        var headers = request.headers
        headers["Authorization"] = "Bearer \(token)"
        
        return HTTPRequest(
            method: request.method,
            url: request.url,
            headers: headers,
            body: request.body,
            timeout: request.timeout
        )
    }
}

public protocol AsyncTokenProvider: Sendable {
    func getCurrentToken() async throws -> String
    func refreshToken() async throws -> String
}

// Implementation using async/await throughout
public struct KeychainTokenProvider: AsyncTokenProvider {
    public func getCurrentToken() async throws -> String {
        // Async keychain access
        return try await withCheckedThrowingContinuation { continuation in
            // Keychain operation...
        }
    }
    
    public func refreshToken() async throws -> String {
        // Async network call to refresh token
        let response = try await URLSession.shared.data(from: refreshURL)
        // Process response...
    }
}
```

---

## Error Handling

### Rich Error Context with Sendable

Error types provide rich context while maintaining Sendable compliance:

```swift
public struct HTTPError: Error, Sendable, LocalizedError {
    public let category: Category
    public let request: HTTPRequest?
    public let response: HTTPResponse?
    public let underlyingError: (any Error)?
    public let timestamp: Date
    public let context: [String: String]
    
    public enum Category: Sendable, Hashable {
        case network(NetworkError)
        case http(HTTPStatus)
        case decoding(String)
        case encoding(String)
        case timeout
        case cancelled
        case configuration(String)
        case middleware(String)
        case circuitBreaker(CircuitBreakerError)
    }
    
    // Error analysis properties
    public var severity: ErrorSeverity {
        switch category {
        case .network(.sslError), .configuration:
            return .critical
        case .network(.noConnection), .timeout:
            return .high
        case .http(let status) where status.rawValue >= 500:
            return .high
        case .http(let status) where status.rawValue >= 400:
            return .medium
        default:
            return .low
        }
    }
    
    public var recoveryStrategy: RecoveryStrategy {
        switch category {
        case .network(.noConnection), .timeout:
            return .retryWithDelay
        case .network(.serverUnreachable):
            return .retryWithBackoff
        case .http(let status) where status.rawValue == 401:
            return .refreshAuthentication
        case .http(let status) where status.rawValue >= 500:
            return .retryWithBackoff
        case .cancelled:
            return .none
        default:
            return .userAction
        }
    }
    
    // Sendable error handling
    public var isRetryable: Bool {
        switch recoveryStrategy {
        case .retryWithDelay, .retryWithBackoff, .refreshAuthentication:
            return true
        case .none, .userAction:
            return false
        }
    }
}

public enum ErrorSeverity: Sendable, CaseIterable {
    case low, medium, high, critical
}

public enum RecoveryStrategy: Sendable {
    case none
    case retryWithDelay
    case retryWithBackoff
    case refreshAuthentication
    case userAction
}
```

### Async Error Recovery

```swift
public struct IntelligentErrorRecovery {
    private let strategies: [any AsyncErrorRecoveryStrategy]
    
    public func recover(from error: HTTPError, for request: HTTPRequest) async throws -> HTTPResponse {
        for strategy in strategies {
            if await strategy.canRecover(from: error) {
                do {
                    return try await strategy.recover(from: error, for: request)
                } catch {
                    // Strategy failed, try next one
                    continue
                }
            }
        }
        
        // No strategy could recover
        throw error
    }
}

public protocol AsyncErrorRecoveryStrategy: Sendable {
    func canRecover(from error: HTTPError) async -> Bool
    func recover(from error: HTTPError, for request: HTTPRequest) async throws -> HTTPResponse
}

public struct AsyncAuthenticationRecoveryStrategy: AsyncErrorRecoveryStrategy {
    private let tokenProvider: any AsyncTokenProvider
    private let client: any HTTPClient
    
    public func canRecover(from error: HTTPError) async -> Bool {
        guard case .http(let status) = error.category,
              status.rawValue == 401 else {
            return false
        }
        
        return await tokenProvider.canRefresh()
    }
    
    public func recover(from error: HTTPError, for request: HTTPRequest) async throws -> HTTPResponse {
        // Async token refresh
        let newToken = try await tokenProvider.refreshToken()
        
        // Retry with new token
        var headers = request.headers
        headers["Authorization"] = "Bearer \(newToken)"
        
        let retryRequest = HTTPRequest(
            method: request.method,
            url: request.url,
            headers: headers,
            body: request.body,
            timeout: request.timeout
        )
        
        return try await client.execute(retryRequest)
    }
}
```

---

## Migration Benefits

### Before: Swift 5 + Completion Handlers

```swift
// Legacy approach - not thread-safe, complex error handling
class LegacyNetworkManager {
    private var authToken: String? // Not thread-safe
    private let session = URLSession.shared
    
    func fetchUser(id: String, completion: @escaping (Result<User, Error>) -> Void) {
        guard let url = URL(string: "https://api.example.com/users/\(id)") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async { // Manual queue management
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(NetworkError.noData))
                    return
                }
                
                do {
                    let user = try JSONDecoder().decode(User.self, from: data)
                    completion(.success(user))
                } catch {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
}
```

### After: Swift 6 + ModernNetworking

```swift
// Modern approach - thread-safe, structured concurrency, rich error handling
struct ModernNetworkManager: Sendable {
    private let client: NetworkClient
    
    init(authToken: String) {
        self.client = NetworkClient {
            BaseURL("https://api.example.com")
            
            Authentication {
                BearerToken(authToken)
                RefreshStrategy.automatic()
            }
            
            Retry {
                MaxAttempts(3)
                BackoffStrategy.exponential()
                RetryWhen.networkErrors()
            }
            
            EnableLogging()
        }
    }
    
    func fetchUser(id: String) async throws -> User {
        let response = try await client.execute {
            GET("/users/\(id)")
        }
        
        return try response.decode(User.self)
    }
    
    // Natural concurrent operations
    func fetchUserProfile(id: String) async throws -> UserProfile {
        async let user = client.execute { GET("/users/\(id)") }
        async let posts = client.execute { GET("/users/\(id)/posts") }
        async let followers = client.execute { GET("/users/\(id)/followers") }
        
        let (userResponse, postsResponse, followersResponse) = try await (user, posts, followers)
        
        return UserProfile(
            user: try userResponse.decode(User.self),
            posts: try postsResponse.decode([Post].self),
            followers: try followersResponse.decode([User].self)
        )
    }
}
```

### Key Improvements Summary

| Aspect | Swift 5 + Legacy | Swift 6 + ModernNetworking |
|--------|-------------------|----------------------------|
| **Thread Safety** | Manual synchronization | Automatic with Sendable |
| **Error Handling** | Generic Error types | Rich HTTPError with context |
| **Concurrency** | Completion handlers | Natural async/await |
| **Configuration** | Imperative setup | Declarative DSL |
| **Type Safety** | Runtime errors | Compile-time guarantees |
| **Code Generation** | Manual implementation | Swift macros |
| **Testing** | Complex mocking | Protocol-based testing |
| **Performance** | Manual optimization | Built-in connection pooling |
| **Cancellation** | Manual tracking | Automatic with Task |
| **Memory Safety** | Potential retain cycles | Actor isolation |

ModernNetworking's Swift 6 implementation provides a comprehensive, safe, and performant foundation for modern iOS, macOS, and cross-platform Swift applications.