# Networking Advanced Usage Guide

```swift
import Foundation
import CryptoKit
```

## Table of Contents

1. [Advanced Request Patterns](#advanced-request-patterns)
2. [Custom Middleware Development](#custom-middleware-development)
3. [Response Processing Pipelines](#response-processing-pipelines)
4. [Error Recovery Strategies](#error-recovery-strategies)
5. [Performance Optimization](#performance-optimization)
6. [Security Best Practices](#security-best-practices)
7. [Testing Advanced Scenarios](#testing-advanced-scenarios)
8. [Integration Patterns](#integration-patterns)
9. [Troubleshooting Guide](#troubleshooting-guide)

---

## Advanced Request Patterns

### 1. Dynamic Request Building

Build requests dynamically based on runtime conditions:

```swift
func buildSearchRequest(
    query: String,
    filters: [SearchFilter],
    pagination: Pagination?,
    user: User?
) async throws -> HTTPRequest {
    
    return try HTTPRequest {
        GET("/search")
        QueryParam("q", query)
        
        // Dynamic filters
        for filter in filters {
            QueryParam(filter.key, filter.value)
        }
        
        // Conditional pagination
        if let pagination = pagination {
            QueryParam("page", "\(pagination.page)")
            QueryParam("limit", "\(pagination.limit)")
        }
        
        // Conditional authentication
        if let user = user {
            BearerAuth(user.accessToken)
        }
        
        // Dynamic headers based on user preferences
        if user?.prefersCompression == true {
            Header("Accept-Encoding", "gzip, deflate")
        }
        
        // Conditional timeout based on network conditions
        if await NetworkMonitor.shared.isSlowNetwork {
            Timeout(60.0)
        } else {
            Timeout(30.0)
        }
    }
}
```

### 2. Request Templating System

Create reusable request templates:

```swift
protocol RequestTemplate {
    func buildRequest() async throws -> [any RequestComponent]
}

struct PaginatedAPIRequest: RequestTemplate {
    let endpoint: String
    let page: Int
    let limit: Int
    let authToken: String?
    
    func buildRequest() async throws -> [any RequestComponent] {
        var components: [any RequestComponent] = [
            GET(endpoint),
            QueryParam("page", "\(page)"),
            QueryParam("limit", "\(limit)"),
            Header("Accept", "application/json")
        ]
        
        if let token = authToken {
            components.append(BearerAuth(token))
        }
        
        return components
    }
}

extension NetworkClient {
    func execute<T: RequestTemplate>(template: T) async throws -> HTTPResponse {
        let components = try await template.buildRequest()
        return try await execute {
            RequestBuilder.buildFromComponents(components)
        }
    }
}

// Usage
let template = PaginatedAPIRequest(
    endpoint: "/users",
    page: 1,
    limit: 50,
    authToken: currentUser.token
)

let response = try await client.execute(template: template)
```

### 3. Conditional Request Execution

Execute requests based on complex conditions:

```swift
struct ConditionalRequestExecutor {
    let client: NetworkClient
    
    func executeWithFallbacks(
        primaryRequest: () throws -> [any RequestComponent],
        fallbackRequests: [() throws -> [any RequestComponent]],
        conditions: [(HTTPError) -> Bool]
    ) async throws -> HTTPResponse {
        
        // Try primary request
        do {
            return try await client.execute {
                RequestBuilder.buildFromComponents(try primaryRequest())
            }
        } catch let error as HTTPError {
            
            // Check fallback conditions
            for (index, condition) in conditions.enumerated() {
                if condition(error) && index < fallbackRequests.count {
                    do {
                        return try await client.execute {
                            RequestBuilder.buildFromComponents(try fallbackRequests[index]())
                        }
                    } catch {
                        continue // Try next fallback
                    }
                }
            }
            
            throw error // No fallback worked
        }
    }
}

// Usage
let executor = ConditionalRequestExecutor(client: client)

let response = try await executor.executeWithFallbacks(
    primaryRequest: {
        [GET("/api/v2/users"), BearerAuth(token)]
    },
    fallbackRequests: [
        { [GET("/api/v1/users"), BearerAuth(token)] },  // API v1 fallback
        { [GET("/users"), BasicAuth(username: user, password: pass)] }  // Basic auth fallback
    ],
    conditions: [
        { error in // Use v1 API if v2 returns 404
            if case .http(let status) = error.category {
                return status.rawValue == 404
            }
            return false
        },
        { error in // Use basic auth if bearer auth fails
            if case .http(let status) = error.category {
                return status.rawValue == 401
            }
            return false
        }
    ]
)
```

### 4. Batch Request Processing

Process multiple requests efficiently:

```swift
struct BatchRequestProcessor {
    let client: NetworkClient
    
    func executeBatch<T: Codable>(
        requests: [BatchRequest<T>],
        maxConcurrency: Int = 5
    ) async throws -> [BatchResult<T>] {
        
        return try await withThrowingTaskGroup(of: (Int, BatchResult<T>).self) { group in
            var results: [BatchResult<T>] = Array(repeating: .failure(BatchError.notExecuted), count: requests.count)
            
            // Process requests with limited concurrency using TaskGroup
            var activeTaskCount = 0
            
            for (index, request) in requests.enumerated() {
                // Wait if we've reached the concurrency limit
                while activeTaskCount >= maxConcurrency {
                    if let (completedIndex, result) = try await group.next() {
                        results[completedIndex] = result
                        activeTaskCount -= 1
                    }
                }
                
                activeTaskCount += 1
                group.addTask {
                    do {
                        let response = try await self.client.execute {
                            RequestBuilder.buildFromComponents(request.components)
                        }
                        let decoded = try response.decode(T.self)
                        return (index, .success(decoded))
                    } catch {
                        return (index, .failure(error))
                    }
                }
            }
            
            // Collect remaining results
            while activeTaskCount > 0 {
                if let (completedIndex, result) = try await group.next() {
                    results[completedIndex] = result
                    activeTaskCount -= 1
                }
            }
            
            return results
        }
    }
}

struct BatchRequest<T: Codable> {
    let id: String
    let components: [any RequestComponent]
    let type: T.Type
}

enum BatchResult<T> {
    case success(T)
    case failure(Error)
}
```

---

## Custom Middleware Development

### 1. Request Transformation Middleware

Create middleware that transforms requests based on complex logic:

```swift
struct APIVersionMiddleware: HTTPRequestMiddleware {
    let versionStrategy: VersionStrategy
    
    enum VersionStrategy {
        case header(String)
        case queryParameter(String)
        case urlPath(String)
        case acceptHeader(String)
    }
    
    func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
        switch versionStrategy {
        case .header(let version):
            var headers = request.headers
            headers["API-Version"] = version
            return request.with(headers: headers)
            
        case .queryParameter(let version):
            let components = URLComponents(url: request.url, resolvingAgainstBaseURL: false)
            var queryItems = components?.queryItems ?? []
            queryItems.append(URLQueryItem(name: "version", value: version))
            
            var newComponents = components
            newComponents?.queryItems = queryItems
            
            guard let newURL = newComponents?.url else {
                throw HTTPError(category: .configuration("Invalid URL after adding version"))
            }
            
            return request.with(url: newURL)
            
        case .urlPath(let version):
            let newPath = "/\(version)" + request.url.path
            let newURL = request.url.appendingPathComponent(newPath)
            return request.with(url: newURL)
            
        case .acceptHeader(let version):
            var headers = request.headers
            headers["Accept"] = "application/vnd.api+json;version=\(version)"
            return request.with(headers: headers)
        }
    }
}
```

### 2. Response Processing Middleware

Middleware that processes responses before they reach the client:

```swift
struct ResponseTransformationMiddleware: HTTPResponseMiddleware {
    let transformations: [ResponseTransformation]
    
    func processResponse(
        _ response: HTTPResponse,
        for request: HTTPRequest
    ) async throws -> HTTPResponse {
        
        var currentResponse = response
        
        for transformation in transformations {
            currentResponse = try await transformation.transform(currentResponse, for: request)
        }
        
        return currentResponse
    }
}

protocol ResponseTransformation: Sendable {
    func transform(_ response: HTTPResponse, for request: HTTPRequest) async throws -> HTTPResponse
}

struct DataDecompressionTransformation: ResponseTransformation {
    func transform(_ response: HTTPResponse, for request: HTTPRequest) async throws -> HTTPResponse {
        guard let body = response.body,
              let contentEncoding = response.headers["Content-Encoding"]?.lowercased(),
              contentEncoding.contains("gzip") else {
            return response
        }
        
        // Note: This example requires a custom Data extension or third-party library for gzip decompression
        let decompressedData = try decompressGzipData(body)
        
        var newHeaders = response.headers
        newHeaders.removeValue(forKey: "Content-Encoding")
        newHeaders["Content-Length"] = "\(decompressedData.count)"
        
        return HTTPResponse(
            request: response.request,
            status: response.status,
            headers: newHeaders,
            body: decompressedData
        )
    }
    
    // Helper function for gzip decompression (requires custom implementation)
    private func decompressGzipData(_ data: Data) throws -> Data {
        // In a real implementation, you would use:
        // - A third-party library like SwiftNIO's NIOGzip
        // - Apple's Compression framework
        // - Or a custom implementation using zlib
        
        // Example using Apple's Compression framework:
        // return try data.decompressed(using: .zlib)
        
        // For this documentation example, return the data as-is
        return data
    }
}

struct ResponseEnrichmentTransformation: ResponseTransformation {
    func transform(_ response: HTTPResponse, for request: HTTPRequest) async throws -> HTTPResponse {
        guard let body = response.body,
              let json = try JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            return response
        }
        
        // Add metadata to response
        var enrichedJSON = json
        enrichedJSON["_metadata"] = [
            "requestId": request.headers["X-Request-ID"] ?? "unknown",
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "processingTime": response.headers["X-Processing-Time"] ?? "unknown"
        ]
        
        let enrichedBody = try JSONSerialization.data(withJSONObject: enrichedJSON)
        
        return HTTPResponse(
            request: response.request,
            status: response.status,
            headers: response.headers,
            body: enrichedBody
        )
    }
}
```

### 3. Advanced Error Handling Middleware

First, let's define the error handling middleware protocol:

```swift
protocol HTTPErrorMiddleware: Sendable {
    func handleError(
        _ error: HTTPError,
        for request: HTTPRequest
    ) async throws -> HTTPResponse
}
```

Sophisticated error handling with recovery strategies:

```swift
struct IntelligentErrorMiddleware: HTTPErrorMiddleware {
    let strategies: [ErrorRecoveryStrategy]
    let analytics: AnalyticsService
    
    func handleError(
        _ error: HTTPError,
        for request: HTTPRequest
    ) async throws -> HTTPResponse {
        
        // Log error for analytics
        await analytics.logError(error, request: request)
        
        // Try recovery strategies in order
        for strategy in strategies {
            if await strategy.canHandle(error, for: request) {
                do {
                    let recoveredResponse = try await strategy.recover(error, for: request)
                    await analytics.logRecovery(strategy: strategy, for: error)
                    return recoveredResponse
                } catch {
                    // Strategy failed, try next one
                    continue
                }
            }
        }
        
        // No strategy could handle the error
        throw error
    }
}

protocol ErrorRecoveryStrategy: Sendable {
    func canHandle(_ error: HTTPError, for request: HTTPRequest) async -> Bool
    func recover(_ error: HTTPError, for request: HTTPRequest) async throws -> HTTPResponse
}

struct TokenRefreshStrategy: ErrorRecoveryStrategy {
    let tokenManager: TokenManager
    let client: HTTPClient
    
    func canHandle(_ error: HTTPError, for request: HTTPRequest) async -> Bool {
        if case .http(let status) = error.category {
            return status.rawValue == 401 && request.headers["Authorization"]?.hasPrefix("Bearer") == true
        }
        return false
    }
    
    func recover(_ error: HTTPError, for request: HTTPRequest) async throws -> HTTPResponse {
        // Refresh token
        let newToken = try await tokenManager.refreshToken()
        
        // Retry request with new token
        var newHeaders = request.headers
        newHeaders["Authorization"] = "Bearer \(newToken)"
        
        let updatedRequest = HTTPRequest(
            method: request.method,
            url: request.url,
            headers: newHeaders,
            body: request.body,
            timeout: request.timeout
        )
        
        return try await client.execute(updatedRequest)
    }
}

struct CacheFallbackStrategy: ErrorRecoveryStrategy {
    let cache: ResponseCache
    
    func canHandle(_ error: HTTPError, for request: HTTPRequest) async -> Bool {
        // Only for GET requests and network errors
        return request.method == .get && 
               (error.category == .timeout || 
                error.category == .network(.noConnection))
    }
    
    func recover(_ error: HTTPError, for request: HTTPRequest) async throws -> HTTPResponse {
        if let cachedResponse = await cache.getCachedResponse(for: request) {
            // Return stale cache with warning header
            var headers = cachedResponse.headers
            headers["X-Cache-Status"] = "stale-fallback"
            
            return HTTPResponse(
                request: request,
                status: cachedResponse.status,
                headers: headers,
                body: cachedResponse.body
            )
        }
        
        throw error // No cached response available
    }
}
```

---

## Response Processing Pipelines

### 1. Complex Validation Pipeline

Create sophisticated response validation:

```swift
struct ValidationPipeline {
    let validators: [ResponseValidator]
    
    func validate(_ response: HTTPResponse, for request: HTTPRequest) async throws {
        for validator in validators {
            try await validator.validate(response, for: request)
        }
    }
}

protocol ResponseValidator: Sendable {
    func validate(_ response: HTTPResponse, for request: HTTPRequest) async throws
}

struct StatusCodeValidator: ResponseValidator {
    let validStatusCodes: Set<Int>
    
    init(validStatusCodes: Set<Int>) {
        self.validStatusCodes = validStatusCodes
    }
    
    func validate(_ response: HTTPResponse, for request: HTTPRequest) async throws {
        guard validStatusCodes.contains(response.status.rawValue) else {
            throw ValidationError.invalidStatusCode(
                expected: validStatusCodes,
                actual: response.status.rawValue,
                response: response
            )
        }
    }
}

struct ContentTypeValidator: ResponseValidator {
    let expectedContentTypes: Set<String>
    
    func validate(_ response: HTTPResponse, for request: HTTPRequest) async throws {
        guard let contentType = response.headers["Content-Type"] else {
            throw ValidationError.missingContentType
        }
        
        let baseContentType = contentType.components(separatedBy: ";").first?.trimmingCharacters(in: .whitespaces) ?? ""
        
        guard expectedContentTypes.contains(baseContentType) else {
            throw ValidationError.invalidContentType(
                expected: expectedContentTypes,
                actual: baseContentType
            )
        }
    }
}

struct ResponseSizeValidator: ResponseValidator {
    let maxSize: Int
    
    func validate(_ response: HTTPResponse, for request: HTTPRequest) async throws {
        let bodySize = response.body?.count ?? 0
        guard bodySize <= maxSize else {
            throw ValidationError.responseTooLarge(
                size: bodySize,
                maxSize: maxSize
            )
        }
    }
}

struct CustomBusinessLogicValidator: ResponseValidator {
    let validationRules: [BusinessRule]
    
    func validate(_ response: HTTPResponse, for request: HTTPRequest) async throws {
        guard let body = response.body,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            return
        }
        
        for rule in validationRules {
            try await rule.validate(json, response: response, request: request)
        }
    }
}

protocol BusinessRule: Sendable {
    func validate(_ json: [String: Any], response: HTTPResponse, request: HTTPRequest) async throws
}
```

### 2. Data Transformation Pipeline

Transform response data through multiple stages:

```swift
struct DataTransformationPipeline<Input, Output> {
    let transformers: [any DataTransformer]
    
    func transform(_ input: Input) async throws -> Output {
        var currentData: Any = input
        
        for transformer in transformers {
            currentData = try await transformer.transform(currentData)
        }
        
        guard let result = currentData as? Output else {
            throw TransformationError.invalidOutputType(
                expected: Output.self,
                actual: type(of: currentData)
            )
        }
        
        return result
    }
}

protocol DataTransformer: Sendable {
    func transform(_ input: Any) async throws -> Any
}

struct JSONDecodingTransformer<T: Codable>: DataTransformer {
    let type: T.Type
    let decoder: JSONDecoder
    
    init(type: T.Type, decoder: JSONDecoder = JSONDecoder()) {
        self.type = type
        self.decoder = decoder
    }
    
    func transform(_ input: Any) async throws -> Any {
        guard let data = input as? Data else {
            throw TransformationError.invalidInputType(
                expected: Data.self,
                actual: type(of: input)
            )
        }
        
        return try decoder.decode(type, from: data)
    }
}

struct DataFilterTransformer: DataTransformer {
    let filterPredicate: (Any) async -> Bool
    
    func transform(_ input: Any) async throws -> Any {
        if await filterPredicate(input) {
            return input
        } else {
            throw TransformationError.dataFiltered
        }
    }
}

struct DataMappingTransformer: DataTransformer {
    let mapping: (Any) async throws -> Any
    
    func transform(_ input: Any) async throws -> Any {
        return try await mapping(input)
    }
}

// Usage
let pipeline = DataTransformationPipeline<Data, [User]>(transformers: [
    JSONDecodingTransformer(type: APIResponse<[User]>.self),
    DataMappingTransformer { input in
        guard let apiResponse = input as? APIResponse<[User]> else {
            throw TransformationError.invalidType
        }
        return apiResponse.data
    },
    DataFilterTransformer { input in
        guard let users = input as? [User] else { return false }
        return users.count > 0 // Only return non-empty arrays
    }
])

let transformedData = try await pipeline.transform(responseData)
```

---

## Error Recovery Strategies

### 1. Intelligent Retry with Adaptive Backoff

Implement smart retry logic that adapts to server behavior:

```swift
actor AdaptiveRetryMiddleware: HTTPErrorMiddleware {
    private var serverResponseTimes: [String: [TimeInterval]] = [:]
    private var serverFailureRates: [String: Double] = [:]
    
    let baseConfiguration: RetryConfiguration
    
    init(baseConfiguration: RetryConfiguration) {
        self.baseConfiguration = baseConfiguration
    }
    
    func handleError(_ error: HTTPError, for request: HTTPRequest) async throws -> HTTPResponse {
        let serverKey = request.url.host ?? "unknown"
        
        // Update server statistics
        await updateFailureRate(for: serverKey)
        
        // Calculate adaptive retry parameters
        let adaptedConfig = await calculateAdaptiveConfig(for: serverKey)
        
        return try await performAdaptiveRetry(
            error: error,
            request: request,
            config: adaptedConfig
        )
    }
    
    private func updateFailureRate(for serverKey: String) async {
        let currentRate = serverFailureRates[serverKey] ?? 0.0
        let newRate = min(currentRate + 0.1, 1.0) // Increase failure rate
        serverFailureRates[serverKey] = newRate
    }
    
    private func calculateAdaptiveConfig(for serverKey: String) async -> AdaptiveRetryConfiguration {
        let failureRate = serverFailureRates[serverKey] ?? 0.0
        let avgResponseTime = calculateAverageResponseTime(for: serverKey)
        
        // Adapt retry behavior based on server health
        let maxAttempts: Int
        let baseDelay: TimeInterval
        let backoffMultiplier: Double
        
        if failureRate > 0.5 {
            // Server is unhealthy - more conservative retries
            maxAttempts = max(1, baseConfiguration.maxAttempts - 1)
            baseDelay = baseConfiguration.baseDelay * 2.0
            backoffMultiplier = 3.0
        } else if avgResponseTime > 5.0 {
            // Server is slow - longer delays
            maxAttempts = baseConfiguration.maxAttempts
            baseDelay = baseConfiguration.baseDelay * 1.5
            backoffMultiplier = 2.5
        } else {
            // Server is healthy - normal retries
            maxAttempts = baseConfiguration.maxAttempts
            baseDelay = baseConfiguration.baseDelay
            backoffMultiplier = baseConfiguration.backoffMultiplier
        }
        
        return AdaptiveRetryConfiguration(
            maxAttempts: maxAttempts,
            baseDelay: baseDelay,
            backoffMultiplier: backoffMultiplier,
            jitterStrategy: .decorrelated
        )
    }
    
    private func calculateAverageResponseTime(for serverKey: String) -> TimeInterval {
        let responseTimes = serverResponseTimes[serverKey] ?? []
        guard !responseTimes.isEmpty else { return 0.0 }
        
        return responseTimes.reduce(0, +) / Double(responseTimes.count)
    }
    
    private func performAdaptiveRetry(
        error: HTTPError,
        request: HTTPRequest,
        config: AdaptiveRetryConfiguration
    ) async throws -> HTTPResponse {
        var lastError = error
        
        for attempt in 1...config.maxAttempts {
            let delay = config.calculateDelay(for: attempt)
            
            // Exponential backoff with jitter
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            
            do {
                let startTime = Date()
                let response = try await executeRequest(request)
                let responseTime = Date().timeIntervalSince(startTime)
                
                // Record successful response time
                await recordResponseTime(responseTime, for: request.url.host ?? "unknown")
                
                return response
            } catch let newError as HTTPError {
                lastError = newError
                
                // Decide whether to continue retrying
                if !shouldContinueRetrying(newError, attempt: attempt, config: config) {
                    break
                }
            }
        }
        
        throw lastError
    }
    
    private func recordResponseTime(_ time: TimeInterval, for serverKey: String) async {
        var times = serverResponseTimes[serverKey] ?? []
        times.append(time)
        
        // Keep only last 100 response times
        if times.count > 100 {
            times.removeFirst(times.count - 100)
        }
        
        serverResponseTimes[serverKey] = times
    }
    
    private func shouldContinueRetrying(
        _ error: HTTPError,
        attempt: Int,
        config: AdaptiveRetryConfiguration
    ) -> Bool {
        // Custom retry logic based on error type and attempt number
        switch error.category {
        case .http(let status) where status.rawValue >= 500:
            return attempt < config.maxAttempts
        case .network:
            return attempt < config.maxAttempts
        case .timeout:
            return attempt < min(2, config.maxAttempts) // Fewer retries for timeouts
        default:
            return false
        }
    }
}
```

### 2. Circuit Breaker with Health Monitoring

Advanced circuit breaker that monitors endpoint health:

```swift
actor HealthMonitoringCircuitBreaker: HTTPErrorMiddleware {
    private var endpointStates: [String: CircuitState] = [:]
    private var healthChecks: [String: HealthCheck] = [:]
    
    struct CircuitState {
        var state: State = .closed
        var failureCount: Int = 0
        var lastFailureTime: Date?
        var lastSuccessTime: Date?
        var consecutiveSuccesses: Int = 0
        
        enum State {
            case closed, open, halfOpen
        }
    }
    
    struct HealthCheck {
        let endpoint: String
        let checkInterval: TimeInterval
        var lastCheck: Date?
        var isHealthy: Bool = true
    }
    
    let configuration: CircuitBreakerConfiguration
    
    init(configuration: CircuitBreakerConfiguration) {
        self.configuration = configuration
        startHealthMonitoring()
    }
    
    func handleError(_ error: HTTPError, for request: HTTPRequest) async throws -> HTTPResponse {
        let endpointKey = getEndpointKey(for: request)
        
        // Get or create circuit state
        var circuitState = endpointStates[endpointKey] ?? CircuitState()
        
        switch circuitState.state {
        case .open:
            // Check if circuit should transition to half-open
            if shouldTransitionToHalfOpen(circuitState) {
                circuitState.state = .halfOpen
                endpointStates[endpointKey] = circuitState
                return try await attemptRequest(request, endpointKey: endpointKey)
            } else {
                throw CircuitBreakerError.circuitOpen(
                    endpoint: endpointKey,
                    nextAttemptTime: calculateNextAttemptTime(circuitState)
                )
            }
            
        case .halfOpen:
            // In half-open state, allow limited requests
            return try await attemptRequest(request, endpointKey: endpointKey)
            
        case .closed:
            // Record failure and potentially open circuit
            circuitState.failureCount += 1
            circuitState.lastFailureTime = Date()
            
            if circuitState.failureCount >= configuration.failureThreshold {
                circuitState.state = .open
                
                // Schedule health check
                scheduleHealthCheck(for: endpointKey)
            }
            
            endpointStates[endpointKey] = circuitState
            throw error
        }
    }
    
    private func attemptRequest(_ request: HTTPRequest, endpointKey: String) async throws -> HTTPResponse {
        do {
            let response = try await executeRequest(request)
            await recordSuccess(for: endpointKey)
            return response
        } catch {
            await recordFailure(for: endpointKey)
            throw error
        }
    }
    
    private func recordSuccess(for endpointKey: String) async {
        var circuitState = endpointStates[endpointKey] ?? CircuitState()
        circuitState.consecutiveSuccesses += 1
        circuitState.lastSuccessTime = Date()
        
        if circuitState.consecutiveSuccesses >= configuration.successThreshold {
            circuitState.state = .closed
            circuitState.failureCount = 0
            circuitState.consecutiveSuccesses = 0
        }
        
        endpointStates[endpointKey] = circuitState
    }
    
    private func recordFailure(for endpointKey: String) async {
        var circuitState = endpointStates[endpointKey] ?? CircuitState()
        circuitState.failureCount += 1
        circuitState.lastFailureTime = Date()
        circuitState.consecutiveSuccesses = 0
        circuitState.state = .open
        
        endpointStates[endpointKey] = circuitState
    }
    
    private func startHealthMonitoring() {
        Task.detached { [weak self] in
            while !Task.isCancelled {
                await self?.performHealthChecks()
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
            }
        }
    }
    
    private func performHealthChecks() async {
        for (endpointKey, var healthCheck) in healthChecks {
            let now = Date()
            
            if let lastCheck = healthCheck.lastCheck,
               now.timeIntervalSince(lastCheck) < healthCheck.checkInterval {
                continue // Skip this check
            }
            
            // Perform health check
            let isHealthy = await checkEndpointHealth(endpointKey)
            healthCheck.isHealthy = isHealthy
            healthCheck.lastCheck = now
            
            healthChecks[endpointKey] = healthCheck
            
            // Update circuit state based on health
            if isHealthy, var circuitState = endpointStates[endpointKey] {
                if circuitState.state == .open {
                    circuitState.state = .halfOpen
                    endpointStates[endpointKey] = circuitState
                }
            }
        }
    }
    
    private func checkEndpointHealth(_ endpointKey: String) async -> Bool {
        // Implement health check logic (e.g., HEAD request)
        do {
            let healthCheckURL = URL(string: "\(endpointKey)/health") ?? URL(string: endpointKey)!
            let request = HTTPRequest(method: .head, url: healthCheckURL)
            let response = try await executeRequest(request)
            return response.status.isSuccess
        } catch {
            return false
        }
    }
    
    private func scheduleHealthCheck(for endpointKey: String) {
        healthChecks[endpointKey] = HealthCheck(
            endpoint: endpointKey,
            checkInterval: configuration.healthCheckInterval,
            lastCheck: nil,
            isHealthy: false
        )
    }
}
```

---

## Performance Optimization

### 1. Connection Pool Management

Optimize connection usage for high-performance scenarios:

```swift
struct ConnectionPoolManager {
    let configuration: ConnectionPoolConfiguration
    
    struct ConnectionPoolConfiguration {
        let maxConnectionsPerHost: Int
        let maxTotalConnections: Int
        let connectionTimeout: TimeInterval
        let keepAliveTimeout: TimeInterval
        let enableHTTP2: Bool
        let enableTCP_NODELAY: Bool
    }
    
    func createOptimizedURLSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        
        // Connection pooling
        configuration.httpMaximumConnectionsPerHost = self.configuration.maxConnectionsPerHost
        configuration.timeoutIntervalForRequest = self.configuration.connectionTimeout
        configuration.timeoutIntervalForResource = self.configuration.keepAliveTimeout
        
        // HTTP/2 and performance optimizations
        configuration.httpShouldUsePipelining = false // HTTP/2 handles multiplexing
        configuration.urlCache = createOptimizedCache()
        
        // TCP optimizations
        configuration.allowsCellularAccess = true
        configuration.waitsForConnectivity = true
        configuration.networkServiceType = .default
        
        return URLSession(configuration: configuration, delegate: nil, delegateQueue: nil)
    }
    
    private func createOptimizedCache() -> URLCache {
        return URLCache(
            memoryCapacity: 50 * 1024 * 1024,    // 50MB memory
            diskCapacity: 200 * 1024 * 1024,     // 200MB disk
            diskPath: "NetworkCache"
        )
    }
}

// Usage with Networking
let poolManager = ConnectionPoolManager(
    configuration: ConnectionPoolManager.ConnectionPoolConfiguration(
        maxConnectionsPerHost: 10,
        maxTotalConnections: 50,
        connectionTimeout: 30.0,
        keepAliveTimeout: 300.0,
        enableHTTP2: true,
        enableTCP_NODELAY: true
    )
)

let optimizedSession = poolManager.createOptimizedURLSession()

let client = NetworkClient {
    BaseURL("https://api.example.com")
    Session {
        CustomURLSession(optimizedSession)
    }
}
```

### 2. Request Batching and Parallelization

Efficiently handle multiple concurrent requests:

```swift
struct RequestBatcher {
    let client: NetworkClient
    let maxConcurrency: Int
    
    func executeBatch<T>(
        requests: [BatchableRequest<T>],
        strategy: BatchingStrategy = .parallel
    ) async throws -> [Result<T, Error>] {
        
        switch strategy {
        case .parallel:
            return try await executeParallel(requests)
        case .sequential:
            return try await executeSequential(requests)
        case .adaptive:
            return try await executeAdaptive(requests)
        }
    }
    
    private func executeParallel<T>(_ requests: [BatchableRequest<T>]) async throws -> [Result<T, Error>] {
        return try await withThrowingTaskGroup(of: (Int, Result<T, Error>).self) { group in
            var results: [Result<T, Error>] = Array(repeating: .failure(BatchError.notExecuted), count: requests.count)
            
            // Limit concurrency
            let semaphore = AsyncSemaphore(value: maxConcurrency)
            
            for (index, request) in requests.enumerated() {
                group.addTask {
                    await semaphore.wait()
                    defer { semaphore.signal() }
                    
                    do {
                        let response = try await self.client.execute {
                            RequestBuilder.buildFromComponents(request.components)
                        }
                        let decoded = try response.decode(T.self)
                        return (index, .success(decoded))
                    } catch {
                        return (index, .failure(error))
                    }
                }
            }
            
            for try await (index, result) in group {
                results[index] = result
            }
            
            return results
        }
    }
    
    private func executeAdaptive<T>(_ requests: [BatchableRequest<T>]) async throws -> [Result<T, Error>] {
        // Start with parallel execution, but adapt based on error rates
        let initialBatchSize = min(maxConcurrency, requests.count)
        var currentConcurrency = initialBatchSize
        var errorRate = 0.0
        
        var remainingRequests = requests
        var allResults: [Result<T, Error>] = []
        
        while !remainingRequests.isEmpty {
            let batchSize = min(currentConcurrency, remainingRequests.count)
            let batch = Array(remainingRequests.prefix(batchSize))
            remainingRequests.removeFirst(batchSize)
            
            let batchResults = try await executeParallel(batch)
            allResults.append(contentsOf: batchResults)
            
            // Calculate error rate
            let errors = batchResults.compactMap { result in
                if case .failure = result { return 1 } else { return 0 }
            }.reduce(0, +)
            
            errorRate = Double(errors) / Double(batchResults.count)
            
            // Adapt concurrency based on error rate
            if errorRate > 0.3 {
                currentConcurrency = max(1, currentConcurrency / 2) // Reduce concurrency
                await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
            } else if errorRate < 0.1 && currentConcurrency < maxConcurrency {
                currentConcurrency = min(maxConcurrency, currentConcurrency + 1) // Increase concurrency
            }
        }
        
        return allResults
    }
}

enum BatchingStrategy {
    case parallel
    case sequential
    case adaptive
}

struct BatchableRequest<T: Codable> {
    let components: [any RequestComponent]
    let type: T.Type
}
```

### 3. Response Streaming for Large Data

Handle large responses efficiently with streaming:

```swift
struct StreamingResponseHandler {
    let client: NetworkClient
    
    func streamLargeResponse<T: Codable>(
        request: HTTPRequest,
        chunkProcessor: @escaping (Data) async throws -> Void,
        finalProcessor: @escaping (Data) async throws -> T
    ) async throws -> T {
        
        // Use URLSession's data task with delegate for streaming
        let streamingSession = createStreamingSession()
        
        return try await withCheckedThrowingContinuation { continuation in
            var accumulatedData = Data()
            
            let task = streamingSession.dataTask(with: URLRequest(url: request.url)) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                if let data = data {
                    accumulatedData.append(data)
                    
                    // Process chunk asynchronously
                    Task {
                        try await chunkProcessor(data)
                    }
                }
            }
            
            // Handle completion
            task.delegate = StreamingTaskDelegate { finalData in
                Task {
                    do {
                        let result = try await finalProcessor(finalData)
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            task.resume()
        }
    }
    
    private func createStreamingSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.urlCache = nil // Disable caching for streaming
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        return URLSession(configuration: config)
    }
}

class StreamingTaskDelegate: NSObject, URLSessionTaskDelegate {
    private let completionHandler: (Data) -> Void
    private var accumulatedData = Data()
    
    init(completionHandler: @escaping (Data) -> Void) {
        self.completionHandler = completionHandler
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if error == nil {
            completionHandler(accumulatedData)
        }
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        accumulatedData.append(data)
    }
}
```

---

## Security Best Practices

### 1. Certificate Pinning Middleware

Implement certificate pinning for enhanced security:

```swift
struct CertificatePinningMiddleware: HTTPRequestMiddleware {
    private let pinnedCertificates: [SecCertificate]
    private let pinnedPublicKeys: [SecKey]
    private let validateCertificateChain: Bool
    
    init(
        pinnedCertificates: [SecCertificate] = [],
        pinnedPublicKeys: [SecKey] = [],
        validateCertificateChain: Bool = true
    ) {
        self.pinnedCertificates = pinnedCertificates
        self.pinnedPublicKeys = pinnedPublicKeys
        self.validateCertificateChain = validateCertificateChain
    }
    
    func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
        // Add certificate validation to the request
        var urlRequest = URLRequest(url: request.url)
        
        // Set up custom URL session with certificate pinning
        let session = createPinnedSession()
        
        // Store session in request context (implementation detail)
        return request.withCustomSession(session)
    }
    
    private func createPinnedSession() -> URLSession {
        let delegate = CertificatePinningDelegate(
            pinnedCertificates: pinnedCertificates,
            pinnedPublicKeys: pinnedPublicKeys,
            validateCertificateChain: validateCertificateChain
        )
        
        return URLSession(
            configuration: .default,
            delegate: delegate,
            delegateQueue: nil
        )
    }
}

class CertificatePinningDelegate: NSObject, URLSessionDelegate {
    private let pinnedCertificates: [SecCertificate]
    private let pinnedPublicKeys: [SecKey]
    private let validateCertificateChain: Bool
    
    init(
        pinnedCertificates: [SecCertificate],
        pinnedPublicKeys: [SecKey],
        validateCertificateChain: Bool
    ) {
        self.pinnedCertificates = pinnedCertificates
        self.pinnedPublicKeys = pinnedPublicKeys
        self.validateCertificateChain = validateCertificateChain
    }
    
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        // Validate certificate chain
        if validateCertificateChain {
            let policy = SecPolicyCreateSSL(true, challenge.protectionSpace.host as CFString)
            SecTrustSetPolicies(serverTrust, policy)
            
            var result: SecTrustResultType = .invalid
            let status = SecTrustEvaluate(serverTrust, &result)
            
            guard status == errSecSuccess,
                  result == .unspecified || result == .proceed else {
                completionHandler(.cancelAuthenticationChallenge, nil)
                return
            }
        }
        
        // Check certificate pinning
        if !pinnedCertificates.isEmpty {
            if validateCertificatePinning(serverTrust: serverTrust) {
                let credential = URLCredential(trust: serverTrust)
                completionHandler(.useCredential, credential)
            } else {
                completionHandler(.cancelAuthenticationChallenge, nil)
            }
            return
        }
        
        // Check public key pinning
        if !pinnedPublicKeys.isEmpty {
            if validatePublicKeyPinning(serverTrust: serverTrust) {
                let credential = URLCredential(trust: serverTrust)
                completionHandler(.useCredential, credential)
            } else {
                completionHandler(.cancelAuthenticationChallenge, nil)
            }
            return
        }
        
        // No pinning configured, use default handling
        completionHandler(.performDefaultHandling, nil)
    }
    
    private func validateCertificatePinning(serverTrust: SecTrust) -> Bool {
        let serverCertificateCount = SecTrustGetCertificateCount(serverTrust)
        
        for i in 0..<serverCertificateCount {
            guard let serverCertificate = SecTrustGetCertificateAtIndex(serverTrust, i) else {
                continue
            }
            
            for pinnedCertificate in pinnedCertificates {
                if CFEqual(serverCertificate, pinnedCertificate) {
                    return true
                }
            }
        }
        
        return false
    }
    
    private func validatePublicKeyPinning(serverTrust: SecTrust) -> Bool {
        let serverCertificateCount = SecTrustGetCertificateCount(serverTrust)
        
        for i in 0..<serverCertificateCount {
            guard let serverCertificate = SecTrustGetCertificateAtIndex(serverTrust, i),
                  let serverPublicKey = SecCertificateCopyKey(serverCertificate) else {
                continue
            }
            
            for pinnedPublicKey in pinnedPublicKeys {
                if CFEqual(serverPublicKey, pinnedPublicKey) {
                    return true
                }
            }
        }
        
        return false
    }
}
```

### 2. Request Signing Middleware

Implement request signing for API authentication:

```swift
struct RequestSigningMiddleware: HTTPRequestMiddleware {
    private let signingKey: String
    private let algorithm: SigningAlgorithm
    private let includeTimestamp: Bool
    
    enum SigningAlgorithm {
        case hmacSHA256
        case hmacSHA512
        case rsa
    }
    
    init(
        signingKey: String,
        algorithm: SigningAlgorithm = .hmacSHA256,
        includeTimestamp: Bool = true
    ) {
        self.signingKey = signingKey
        self.algorithm = algorithm
        self.includeTimestamp = includeTimestamp
    }
    
    func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
        var headers = request.headers
        
        // Add timestamp if required
        if includeTimestamp {
            let timestamp = String(Int(Date().timeIntervalSince1970))
            headers["X-Timestamp"] = timestamp
        }
        
        // Create string to sign
        let stringToSign = createStringToSign(
            method: request.method.rawValue,
            url: request.url,
            headers: headers,
            body: request.body
        )
        
        // Generate signature
        let signature = try generateSignature(for: stringToSign)
        headers["Authorization"] = "Signature \(signature)"
        
        return HTTPRequest(
            method: request.method,
            url: request.url,
            headers: headers,
            body: request.body,
            timeout: request.timeout
        )
    }
    
    private func createStringToSign(
        method: String,
        url: URL,
        headers: [String: String],
        body: Data?
    ) -> String {
        var components: [String] = []
        
        // HTTP method
        components.append(method.uppercased())
        
        // URL path and query
        components.append(url.path)
        if let query = url.query {
            components.append(query)
        }
        
        // Sorted headers (canonical headers)
        let sortedHeaders = headers.sorted { $0.key.lowercased() < $1.key.lowercased() }
        for (key, value) in sortedHeaders {
            components.append("\(key.lowercased()):\(value)")
        }
        
        // Body hash
        if let body = body {
            let bodyHash = SHA256.hash(data: body)
            components.append(bodyHash.compactMap { String(format: "%02x", $0) }.joined())
        }
        
        return components.joined(separator: "\n")
    }
    
    private func generateSignature(for string: String) throws -> String {
        switch algorithm {
        case .hmacSHA256:
            return try generateHMACSignature(for: string, algorithm: .hmacSHA256)
        case .hmacSHA512:
            return try generateHMACSignature(for: string, algorithm: .hmacSHA512)
        case .rsa:
            return try generateRSASignature(for: string)
        }
    }
    
    private func generateHMACSignature(for string: String, algorithm: SigningAlgorithm) throws -> String {
        guard let data = string.data(using: .utf8),
              let keyData = signingKey.data(using: .utf8) else {
            throw SigningError.invalidInput
        }
        
        let key = SymmetricKey(data: keyData)
        let signature: Data
        
        switch algorithm {
        case .hmacSHA256:
            signature = Data(HMAC<SHA256>.authenticationCode(for: data, using: key))
        case .hmacSHA512:
            signature = Data(HMAC<SHA512>.authenticationCode(for: data, using: key))
        case .rsa:
            throw SigningError.unsupportedAlgorithm
        }
        
        return signature.base64EncodedString()
    }
    
    private func generateRSASignature(for string: String) throws -> String {
        // RSA signing implementation
        // This would typically use Security framework or CryptoKit
        throw SigningError.unsupportedAlgorithm
    }
}

enum SigningError: Error {
    case invalidInput
    case unsupportedAlgorithm
    case keyGenerationFailed
    case signingFailed
}
```

This advanced usage guide demonstrates sophisticated patterns for using Networking in complex scenarios, from custom middleware development to performance optimization and security hardening. These patterns enable building robust, high-performance networking applications that scale well in production environments.