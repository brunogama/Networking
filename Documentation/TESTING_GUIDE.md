# ModernNetworking Testing Guide

## Table of Contents

1. [Testing Philosophy](#testing-philosophy)
2. [Unit Testing](#unit-testing)
3. [Integration Testing](#integration-testing)
4. [Mock Implementation](#mock-implementation)
5. [Swift Testing Framework](#swift-testing-framework)
6. [Test Utilities](#test-utilities)
7. [Performance Testing](#performance-testing)
8. [Middleware Testing](#middleware-testing)
9. [End-to-End Testing](#end-to-end-testing)
10. [Best Practices](#best-practices)

---

## Testing Philosophy

ModernNetworking is designed with testability as a core principle:

### Protocol-Based Design
- All major components implement protocols
- Easy mocking and stubbing
- Dependency injection friendly

### Sendable Compliance
- Thread-safe test execution
- Concurrent test scenarios
- Actor-based test state management

### Structured Concurrency
- Natural async/await test patterns
- Proper cancellation testing
- Task group testing

---

## Unit Testing

### Testing NetworkClient

```swift
import Testing
import ModernNetworking

@Test("NetworkClient executes basic GET request")
func testBasicGETRequest() async throws {
    // Arrange
    let expectedURL = URL(string: "https://api.example.com/users")!
    var capturedRequest: HTTPRequest?
    
    let mockClient = MockHTTPClient { request in
        capturedRequest = request
        return HTTPResponse(
            request: request,
            status: .ok,
            body: #"{"users": []}"#.data(using: .utf8)
        )
    }
    
    // Act
    let response = try await mockClient.execute(
        HTTPRequest(method: .get, url: expectedURL)
    )
    
    // Assert
    #expect(capturedRequest?.method == .get)
    #expect(capturedRequest?.url == expectedURL)
    #expect(response.status == .ok)
    #expect(response.isSuccess)
}

@Test("NetworkClient handles request middleware chain")
func testRequestMiddlewareChain() async throws {
    // Arrange
    var middlewareCallOrder: [String] = []
    
    let middleware1 = TestRequestMiddleware("auth") { request in
        middlewareCallOrder.append("auth")
        var headers = request.headers
        headers["Authorization"] = "Bearer token"
        return request.with(headers: headers)
    }
    
    let middleware2 = TestRequestMiddleware("logging") { request in
        middlewareCallOrder.append("logging")
        return request
    }
    
    let client = NetworkClient(
        session: .shared,
        requestMiddlewares: [middleware1, middleware2]
    )
    
    // Act
    _ = try await client.execute(
        HTTPRequest(method: .get, url: URL(string: "https://api.example.com")!)
    )
    
    // Assert
    #expect(middlewareCallOrder == ["auth", "logging"])
}

@Test("NetworkClient handles response middleware chain")
func testResponseMiddlewareChain() async throws {
    // Similar pattern for response middleware
    var processedResponses: [String] = []
    
    let middleware1 = TestResponseMiddleware("metrics") { response, request in
        processedResponses.append("metrics")
        return response
    }
    
    let middleware2 = TestResponseMiddleware("caching") { response, request in
        processedResponses.append("caching")
        return response
    }
    
    let client = NetworkClient(
        session: .shared,
        responseMiddlewares: [middleware1, middleware2]
    )
    
    // Test execution and assertions...
}

@Test("NetworkClient handles error middleware chain")
func testErrorMiddlewareChain() async throws {
    let middleware = TestErrorMiddleware { error, request in
        if case .http(let status) = error.category, status.rawValue == 401 {
            // Return a recovery response
            return HTTPResponse(
                request: request,
                status: .ok,
                body: #"{"recovered": true}"#.data(using: .utf8)
            )
        }
        throw error
    }
    
    let client = NetworkClient(
        session: .shared,
        errorMiddlewares: [middleware]
    )
    
    // Test that 401 errors are recovered
    let mockSession = MockURLSession { _ in
        let httpResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com")!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )!
        return (Data(), httpResponse)
    }
    
    // Continue with test implementation...
}
```

### Testing Request Builders

```swift
@Test("RequestBuilder creates correct GET request")
func testRequestBuilderGET() async throws {
    // Act
    let request = try RequestBuilder.build {
        GET("/users/123")
        Header("Accept", "application/json")
        BearerAuth("test-token")
        Timeout(15.0)
    }
    
    // Assert
    #expect(request.method == .get)
    #expect(request.url.path == "/users/123")
    #expect(request.headers["Accept"] == "application/json")
    #expect(request.headers["Authorization"] == "Bearer test-token")
    #expect(request.timeout == 15.0)
}

@Test("RequestBuilder creates correct POST request with JSON body")
func testRequestBuilderPOST() async throws {
    struct TestData: Codable, Equatable {
        let name: String
        let age: Int
    }
    
    let testData = TestData(name: "John", age: 30)
    
    // Act
    let request = try RequestBuilder.build {
        POST("/users")
        JSONBody(testData)
        Header("Content-Type", "application/json")
    }
    
    // Assert
    #expect(request.method == .post)
    #expect(request.url.path == "/users")
    #expect(request.headers["Content-Type"] == "application/json")
    
    // Verify JSON body
    let decodedData = try JSONDecoder().decode(TestData.self, from: request.body!)
    #expect(decodedData == testData)
}

@Test("RequestBuilder handles query parameters correctly")
func testRequestBuilderQueryParams() async throws {
    // Act
    let request = try RequestBuilder.build {
        GET("/search")
        QueryParam("q", "swift networking")
        QueryParam("limit", "10")
        QueryParam("sort", "relevance")
    }
    
    // Assert
    #expect(request.method == .get)
    #expect(request.url.path == "/search")
    
    let components = URLComponents(url: request.url, resolvingAgainstBaseURL: false)
    let queryItems = components?.queryItems ?? []
    
    #expect(queryItems.contains { $0.name == "q" && $0.value == "swift networking" })
    #expect(queryItems.contains { $0.name == "limit" && $0.value == "10" })
    #expect(queryItems.contains { $0.name == "sort" && $0.value == "relevance" })
}
```

### Testing HTTPError

```swift
@Test("HTTPError categorizes network errors correctly")
func testHTTPErrorNetworkCategories() {
    let request = HTTPRequest(method: .get, url: URL(string: "https://api.example.com")!)
    
    // Test different network error categories
    let noConnectionError = HTTPError.network(.noConnection, request: request)
    #expect(noConnectionError.category == .network(.noConnection))
    #expect(noConnectionError.severity == .high)
    #expect(noConnectionError.isRetryable == true)
    
    let sslError = HTTPError.network(.sslError, request: request)
    #expect(sslError.category == .network(.sslError))
    #expect(sslError.severity == .critical)
    #expect(sslError.requiresUserAction == true)
}

@Test("HTTPError categorizes HTTP status errors correctly")
func testHTTPErrorStatusCategories() {
    let request = HTTPRequest(method: .get, url: URL(string: "https://api.example.com")!)
    
    let unauthorizedError = HTTPError.http(.unauthorized, request: request)
    #expect(unauthorizedError.category == .http(.unauthorized))
    #expect(unauthorizedError.isClientError == true)
    #expect(unauthorizedError.requiresUserAction == true)
    
    let serverError = HTTPError.http(.serverError, request: request)
    #expect(serverError.category == .http(.serverError))
    #expect(serverError.isServerError == true)
    #expect(serverError.isRetryable == true)
}

@Test("HTTPError provides meaningful error descriptions")
func testHTTPErrorDescriptions() {
    let request = HTTPRequest(method: .post, url: URL(string: "https://api.example.com/users")!)
    
    let decodingError = HTTPError(
        category: .decoding("Invalid JSON format"),
        request: request
    )
    
    #expect(decodingError.errorDescription?.contains("Decoding error") == true)
    #expect(decodingError.errorDescription?.contains("Invalid JSON format") == true)
    
    let timeoutError = HTTPError(category: .timeout, request: request)
    #expect(timeoutError.errorDescription == "Request timed out")
}
```

---

## Integration Testing

### Testing with Real Network Calls

```swift
import Testing
import ModernNetworking

@Test("Integration test with JSONPlaceholder API")
func testRealAPIIntegration() async throws {
    let client = NetworkClient {
        BaseURL("https://jsonplaceholder.typicode.com")
        DefaultHeader("Accept", "application/json")
        EnableLogging()
    }
    
    struct Post: Codable {
        let id: Int
        let userId: Int
        let title: String
        let body: String
    }
    
    // Act
    let response = try await client.execute {
        GET("/posts/1")
        Timeout(10.0)
    }
    
    // Assert
    #expect(response.status == .ok)
    #expect(response.headers["Content-Type"]?.contains("application/json") == true)
    
    let post = try response.decode(Post.self)
    #expect(post.id == 1)
    #expect(post.userId == 1)
    #expect(!post.title.isEmpty)
    #expect(!post.body.isEmpty)
}

@Test("Integration test with authentication", .tags(.integration, .auth))
func testAuthenticatedAPIIntegration() async throws {
    // Skip if no test token available
    guard let testToken = ProcessInfo.processInfo.environment["TEST_API_TOKEN"] else {
        throw XCTSkip("TEST_API_TOKEN environment variable not set")
    }
    
    let client = NetworkClient {
        BaseURL("https://api.github.com")
        DefaultHeader("Accept", "application/vnd.github.v3+json")
        Authentication {
            BearerToken(testToken)
        }
    }
    
    struct GitHubUser: Codable {
        let login: String
        let id: Int
        let name: String?
    }
    
    // Act
    let response = try await client.execute {
        GET("/user")
    }
    
    // Assert
    #expect(response.status == .ok)
    let user = try response.decode(GitHubUser.self)
    #expect(!user.login.isEmpty)
    #expect(user.id > 0)
}

@Test("Integration test with retry mechanism", .tags(.integration, .retry))
func testRetryIntegration() async throws {
    var attemptCount = 0
    
    let client = NetworkClient {
        BaseURL("https://httpstat.us")
        Retry {
            MaxAttempts(3)
            InitialDelay(0.5)
            BackoffStrategy.exponential()
            RetryWhen.networkErrors()
        }
    }
    
    // Use httpstat.us to simulate server errors
    do {
        let response = try await client.execute {
            GET("/500")  // Will return 500 status
            Timeout(5.0)
        }
        
        // Should not reach here due to retry failures
        #expect(Bool(false), "Expected request to fail after retries")
    } catch let error as HTTPError {
        #expect(error.category == .http(.serverError))
        // Verify that retries were attempted
        // (This would require custom middleware to track attempts)
    }
}
```

### Testing Configuration DSL

```swift
@Test("NetworkClient configuration DSL works correctly")
func testConfigurationDSL() async throws {
    let baseURL = "https://api.example.com"
    let userAgent = "TestApp/1.0"
    let timeout: TimeInterval = 45.0
    
    let client = NetworkClient {
        BaseURL(baseURL)
        DefaultHeader("User-Agent", userAgent)
        DefaultTimeout(timeout)
        
        Authentication {
            BearerToken("test-token")
            RefreshStrategy.automatic()
        }
        
        Retry {
            MaxAttempts(5)
            BackoffStrategy.exponential()
            InitialDelay(2.0)
        }
        
        Caching {
            Policy.standard()
            Storage.memory(size: .MB(25))
            Duration.ttl(600)
        }
        
        Session {
            AllowsCellular(true)
            WaitsForConnectivity(true)
            MaxConnectionsPerHost(8)
        }
    }
    
    // Test that configuration is applied correctly
    // This would require access to internal configuration state
    // or testing through behavior verification
}
```

---

## Mock Implementation

### Complete Mock HTTPClient

```swift
import Foundation
import ModernNetworking

/// Mock HTTPClient for testing
public struct MockHTTPClient: HTTPClient {
    private let responseHandler: (HTTPRequest) async throws -> HTTPResponse
    
    public init(responseHandler: @escaping (HTTPRequest) async throws -> HTTPResponse) {
        self.responseHandler = responseHandler
    }
    
    public func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        return try await responseHandler(request)
    }
}

/// Mock HTTPClient that can be pre-configured with responses
public struct ConfigurableMockHTTPClient: HTTPClient {
    private let responses: [MockResponse]
    private let defaultResponse: HTTPResponse?
    
    public struct MockResponse {
        let matcher: RequestMatcher
        let response: HTTPResponse
        let delay: TimeInterval?
        
        public init(
            matcher: RequestMatcher,
            response: HTTPResponse,
            delay: TimeInterval? = nil
        ) {
            self.matcher = matcher
            self.response = response
            self.delay = delay
        }
    }
    
    public init(responses: [MockResponse], defaultResponse: HTTPResponse? = nil) {
        self.responses = responses
        self.defaultResponse = defaultResponse
    }
    
    public func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        // Add delay if specified
        for mockResponse in responses {
            if mockResponse.matcher.matches(request) {
                if let delay = mockResponse.delay {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
                return mockResponse.response
            }
        }
        
        // Return default response or throw error
        if let defaultResponse = defaultResponse {
            return defaultResponse
        } else {
            throw HTTPError(
                category: .configuration("No mock response configured for request: \(request)")
            )
        }
    }
}

/// Request matching for mock responses
public struct RequestMatcher {
    private let predicate: (HTTPRequest) -> Bool
    
    public init(predicate: @escaping (HTTPRequest) -> Bool) {
        self.predicate = predicate
    }
    
    public func matches(_ request: HTTPRequest) -> Bool {
        return predicate(request)
    }
    
    // Convenience matchers
    public static func method(_ method: HTTPMethod) -> RequestMatcher {
        return RequestMatcher { $0.method == method }
    }
    
    public static func path(_ path: String) -> RequestMatcher {
        return RequestMatcher { $0.url.path == path }
    }
    
    public static func url(_ url: URL) -> RequestMatcher {
        return RequestMatcher { $0.url == url }
    }
    
    public static func header(_ name: String, value: String) -> RequestMatcher {
        return RequestMatcher { $0.headers[name] == value }
    }
    
    public static func hasHeader(_ name: String) -> RequestMatcher {
        return RequestMatcher { $0.headers[name] != nil }
    }
    
    // Compound matchers
    public static func && (lhs: RequestMatcher, rhs: RequestMatcher) -> RequestMatcher {
        return RequestMatcher { request in
            lhs.matches(request) && rhs.matches(request)
        }
    }
    
    public static func || (lhs: RequestMatcher, rhs: RequestMatcher) -> RequestMatcher {
        return RequestMatcher { request in
            lhs.matches(request) || rhs.matches(request)
        }
    }
}

// Usage example
let mockClient = ConfigurableMockHTTPClient(responses: [
    .init(
        matcher: .method(.get) && .path("/users"),
        response: HTTPResponse(
            request: dummyRequest,
            status: .ok,
            body: usersJSONData
        )
    ),
    .init(
        matcher: .method(.post) && .path("/users"),
        response: HTTPResponse(
            request: dummyRequest,
            status: .created,
            body: createdUserJSONData
        ),
        delay: 0.5 // Simulate network delay
    )
])
```

### Mock Middleware

```swift
// Mock request middleware
public struct TestRequestMiddleware: HTTPRequestMiddleware {
    private let name: String
    private let modifier: (HTTPRequest) async throws -> HTTPRequest
    
    public init(
        _ name: String,
        modifier: @escaping (HTTPRequest) async throws -> HTTPRequest
    ) {
        self.name = name
        self.modifier = modifier
    }
    
    public func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
        return try await modifier(request)
    }
}

// Mock response middleware
public struct TestResponseMiddleware: HTTPResponseMiddleware {
    private let name: String
    private let processor: (HTTPResponse, HTTPRequest) async throws -> HTTPResponse
    
    public init(
        _ name: String,
        processor: @escaping (HTTPResponse, HTTPRequest) async throws -> HTTPResponse
    ) {
        self.name = name
        self.processor = processor
    }
    
    public func processResponse(
        _ response: HTTPResponse,
        for request: HTTPRequest
    ) async throws -> HTTPResponse {
        return try await processor(response, request)
    }
}

// Mock error middleware
public struct TestErrorMiddleware: HTTPErrorMiddleware {
    private let handler: (HTTPError, HTTPRequest) async throws -> HTTPResponse
    
    public init(handler: @escaping (HTTPError, HTTPRequest) async throws -> HTTPResponse) {
        self.handler = handler
    }
    
    public func handleError(
        _ error: HTTPError,
        for request: HTTPRequest
    ) async throws -> HTTPResponse {
        return try await handler(error, request)
    }
}
```

---

## Swift Testing Framework

### Using the New Testing Framework

```swift
import Testing
import ModernNetworking

// Basic test structure
@Test("NetworkClient basic functionality")
func testBasicNetworking() async throws {
    let client = NetworkClient()
    
    let response = try await client.execute(
        HTTPRequest(method: .get, url: URL(string: "https://httpbin.org/get")!)
    )
    
    #expect(response.status == .ok)
}

// Parameterized tests
@Test("HTTP methods work correctly", arguments: [
    (HTTPMethod.get, "/get"),
    (HTTPMethod.post, "/post"),
    (HTTPMethod.put, "/put"),
    (HTTPMethod.delete, "/delete")
])
func testHTTPMethods(method: HTTPMethod, path: String) async throws {
    let client = NetworkClient {
        BaseURL("https://httpbin.org")
    }
    
    let response = try await client.execute {
        Method(method)
        Path(path)
    }
    
    #expect(response.status.isSuccess)
}

// Test with expectations
@Test("Async middleware execution order")
func testMiddlewareOrder() async throws {
    let expectation = Expectation()
    var executionOrder: [String] = []
    
    let middleware1 = TestRequestMiddleware("first") { request in
        executionOrder.append("first")
        return request
    }
    
    let middleware2 = TestRequestMiddleware("second") { request in
        executionOrder.append("second")
        expectation.fulfill()
        return request
    }
    
    let client = NetworkClient(
        requestMiddlewares: [middleware1, middleware2]
    )
    
    _ = try await client.execute(
        HTTPRequest(method: .get, url: URL(string: "https://httpbin.org/get")!)
    )
    
    await expectation.fulfillment(timeout: .seconds(5))
    #expect(executionOrder == ["first", "second"])
}

// Test with tags for organization
@Test("Error handling works correctly", .tags(.errorHandling, .network))
func testErrorHandling() async throws {
    let client = NetworkClient {
        BaseURL("https://httpstat.us")
    }
    
    do {
        _ = try await client.execute {
            GET("/404")
        }
        #expect(Bool(false), "Should have thrown an error")
    } catch let error as HTTPError {
        #expect(error.category == .http(.notFound))
    }
}

// Conditional tests
@Test("Integration test with real API", 
      .enabled(if: ProcessInfo.processInfo.environment["RUN_INTEGRATION_TESTS"] != nil))
func testRealAPIIntegration() async throws {
    // Only runs if environment variable is set
    let client = NetworkClient {
        BaseURL("https://api.github.com")
    }
    
    let response = try await client.execute {
        GET("/")
    }
    
    #expect(response.status == .ok)
}
```

### Test Suites and Organization

```swift
// Test suite for request building
@Suite("Request Building Tests")
struct RequestBuildingTests {
    
    @Test("Basic GET request creation")
    func testBasicGETCreation() async throws {
        let request = try RequestBuilder.build {
            GET("/users")
        }
        
        #expect(request.method == .get)
        #expect(request.url.path == "/users")
    }
    
    @Test("POST request with body")
    func testPOSTWithBody() async throws {
        struct User: Codable {
            let name: String
            let email: String
        }
        
        let user = User(name: "John", email: "john@example.com")
        
        let request = try RequestBuilder.build {
            POST("/users")
            JSONBody(user)
        }
        
        #expect(request.method == .post)
        #expect(request.body != nil)
    }
}

// Test suite for error handling
@Suite("Error Handling Tests")
struct ErrorHandlingTests {
    
    @Test("Network error categorization")
    func testNetworkErrorCategories() {
        let error = HTTPError.network(.noConnection)
        #expect(error.category == .network(.noConnection))
        #expect(error.isRetryable)
    }
    
    @Test("HTTP error categorization")
    func testHTTPErrorCategories() {
        let error = HTTPError.http(.unauthorized)
        #expect(error.category == .http(.unauthorized))
        #expect(error.requiresUserAction)
    }
}

// Test suite for middleware
@Suite("Middleware Tests")
struct MiddlewareTests {
    
    @Test("Request middleware execution")
    func testRequestMiddleware() async throws {
        let middleware = TestRequestMiddleware("test") { request in
            var headers = request.headers
            headers["X-Test"] = "test-value"
            return request.with(headers: headers)
        }
        
        let originalRequest = HTTPRequest(
            method: .get,
            url: URL(string: "https://example.com")!
        )
        
        let modifiedRequest = try await middleware.modifyRequest(originalRequest)
        
        #expect(modifiedRequest.headers["X-Test"] == "test-value")
    }
    
    @Test("Response middleware execution")
    func testResponseMiddleware() async throws {
        let middleware = TestResponseMiddleware("test") { response, request in
            var headers = response.headers
            headers["X-Processed"] = "true"
            return response.with(headers: headers)
        }
        
        let originalResponse = HTTPResponse(
            request: HTTPRequest(method: .get, url: URL(string: "https://example.com")!),
            status: .ok
        )
        
        let processedResponse = try await middleware.processResponse(
            originalResponse,
            for: originalResponse.request
        )
        
        #expect(processedResponse.headers["X-Processed"] == "true")
    }
}
```

---

## Test Utilities

### Request and Response Builders for Tests

```swift
public struct TestHTTPRequestBuilder {
    public static func build(
        method: HTTPMethod = .get,
        url: String = "https://api.example.com/test",
        headers: [String: String] = [:],
        body: Data? = nil,
        timeout: TimeInterval = 30.0
    ) -> HTTPRequest {
        return HTTPRequest(
            method: method,
            url: URL(string: url)!,
            headers: headers,
            body: body,
            timeout: timeout
        )
    }
    
    public static func getRequest(path: String = "/test") -> HTTPRequest {
        return build(method: .get, url: "https://api.example.com\(path)")
    }
    
    public static func postRequest<T: Codable>(
        path: String = "/test",
        body: T
    ) throws -> HTTPRequest {
        let jsonData = try JSONEncoder().encode(body)
        return build(
            method: .post,
            url: "https://api.example.com\(path)",
            headers: ["Content-Type": "application/json"],
            body: jsonData
        )
    }
}

public struct TestHTTPResponseBuilder {
    public static func build(
        for request: HTTPRequest,
        status: HTTPStatus = .ok,
        headers: [String: String] = ["Content-Type": "application/json"],
        body: Data? = nil
    ) -> HTTPResponse {
        return HTTPResponse(
            request: request,
            status: status,
            headers: headers,
            body: body
        )
    }
    
    public static func successResponse<T: Codable>(
        for request: HTTPRequest,
        body: T
    ) throws -> HTTPResponse {
        let jsonData = try JSONEncoder().encode(body)
        return build(
            for: request,
            status: .ok,
            body: jsonData
        )
    }
    
    public static func errorResponse(
        for request: HTTPRequest,
        status: HTTPStatus,
        errorMessage: String? = nil
    ) -> HTTPResponse {
        let body = errorMessage?.data(using: .utf8)
        return build(
            for: request,
            status: status,
            body: body
        )
    }
}
```

### Test Data Generators

```swift
public struct TestDataGenerator {
    public static func randomUser() -> TestUser {
        return TestUser(
            id: Int.random(in: 1...1000),
            name: randomName(),
            email: randomEmail(),
            createdAt: randomDate()
        )
    }
    
    public static func randomUsers(count: Int) -> [TestUser] {
        return (0..<count).map { _ in randomUser() }
    }
    
    public static func randomPost() -> TestPost {
        return TestPost(
            id: Int.random(in: 1...1000),
            userId: Int.random(in: 1...100),
            title: randomTitle(),
            body: randomBody()
        )
    }
    
    private static func randomName() -> String {
        let names = ["Alice", "Bob", "Charlie", "Diana", "Eve", "Frank"]
        return names.randomElement()!
    }
    
    private static func randomEmail() -> String {
        let domains = ["example.com", "test.com", "demo.org"]
        let username = randomName().lowercased()
        return "\(username)@\(domains.randomElement()!)"
    }
    
    private static func randomDate() -> Date {
        let timeInterval = TimeInterval.random(in: 0...31536000) // 1 year
        return Date().addingTimeInterval(-timeInterval)
    }
    
    private static func randomTitle() -> String {
        let titles = [
            "Getting Started with Swift",
            "Advanced Networking Patterns",
            "Testing Best Practices",
            "Performance Optimization Tips"
        ]
        return titles.randomElement()!
    }
    
    private static func randomBody() -> String {
        return "This is a test post body with random content. Lorem ipsum dolor sit amet."
    }
}

public struct TestUser: Codable, Equatable {
    public let id: Int
    public let name: String
    public let email: String
    public let createdAt: Date
    
    public init(id: Int, name: String, email: String, createdAt: Date) {
        self.id = id
        self.name = name
        self.email = email
        self.createdAt = createdAt
    }
}

public struct TestPost: Codable, Equatable {
    public let id: Int
    public let userId: Int
    public let title: String
    public let body: String
    
    public init(id: Int, userId: Int, title: String, body: String) {
        self.id = id
        self.userId = userId
        self.title = title
        self.body = body
    }
}
```

### Assertion Helpers

```swift
public func expectRequest(
    _ request: HTTPRequest,
    hasMethod method: HTTPMethod,
    path: String,
    headers: [String: String] = [:],
    file: StaticString = #file,
    line: UInt = #line
) {
    #expect(request.method == method, "Expected method \(method), got \(request.method)", sourceLocation: SourceLocation(file: file, line: line))
    #expect(request.url.path == path, "Expected path \(path), got \(request.url.path)", sourceLocation: SourceLocation(file: file, line: line))
    
    for (key, value) in headers {
        #expect(request.headers[key] == value, "Expected header \(key): \(value), got \(request.headers[key] ?? "nil")", sourceLocation: SourceLocation(file: file, line: line))
    }
}

public func expectResponse(
    _ response: HTTPResponse,
    hasStatus status: HTTPStatus,
    contentType: String? = nil,
    file: StaticString = #file,
    line: UInt = #line
) {
    #expect(response.status == status, "Expected status \(status), got \(response.status)", sourceLocation: SourceLocation(file: file, line: line))
    
    if let contentType = contentType {
        #expect(response.headers["Content-Type"]?.contains(contentType) == true, "Expected Content-Type to contain \(contentType)", sourceLocation: SourceLocation(file: file, line: line))
    }
}

public func expectError(
    _ error: Error,
    isHTTPError category: HTTPError.Category,
    file: StaticString = #file,
    line: UInt = #line
) {
    guard let httpError = error as? HTTPError else {
        #expect(Bool(false), "Expected HTTPError, got \(type(of: error))", sourceLocation: SourceLocation(file: file, line: line))
        return
    }
    
    #expect(httpError.category == category, "Expected error category \(category), got \(httpError.category)", sourceLocation: SourceLocation(file: file, line: line))
}
```

---

## Performance Testing

### Response Time Testing

```swift
@Test("Response time performance")
func testResponseTimePerformance() async throws {
    let client = NetworkClient {
        BaseURL("https://httpbin.org")
    }
    
    let startTime = CFAbsoluteTimeGetCurrent()
    
    let response = try await client.execute {
        GET("/delay/1") // 1 second delay
    }
    
    let endTime = CFAbsoluteTimeGetCurrent()
    let duration = endTime - startTime
    
    #expect(response.status == .ok)
    #expect(duration >= 1.0) // At least 1 second
    #expect(duration <= 2.0) // But not more than 2 seconds (allowing for network overhead)
}

@Test("Concurrent request performance")
func testConcurrentRequestPerformance() async throws {
    let client = NetworkClient {
        BaseURL("https://httpbin.org")
    }
    
    let requestCount = 10
    let startTime = CFAbsoluteTimeGetCurrent()
    
    try await withThrowingTaskGroup(of: HTTPResponse.self) { group in
        for i in 0..<requestCount {
            group.addTask {
                try await client.execute {
                    GET("/delay/1")
                    Header("X-Request-Index", "\(i)")
                }
            }
        }
        
        var responses: [HTTPResponse] = []
        for try await response in group {
            responses.append(response)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        #expect(responses.count == requestCount)
        // Concurrent requests should not take 10x the time
        #expect(duration <= 3.0) // Allow some overhead for concurrency
    }
}

@Test("Memory usage during large response processing")
func testMemoryUsage() async throws {
    // This would typically use XCTMemoryMetric in XCTest
    // For Swift Testing, we can measure memory manually
    
    let client = NetworkClient {
        BaseURL("https://httpbin.org")
    }
    
    let initialMemory = getMemoryUsage()
    
    // Request large response
    let response = try await client.execute {
        GET("/stream-bytes/1048576") // 1MB response
    }
    
    #expect(response.status == .ok)
    #expect(response.body?.count == 1048576)
    
    let finalMemory = getMemoryUsage()
    let memoryIncrease = finalMemory - initialMemory
    
    // Memory increase should be reasonable (allow for some overhead)
    #expect(memoryIncrease <= 5_000_000) // 5MB limit
}

private func getMemoryUsage() -> Int {
    var info = task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<task_basic_info>.size) / 4
    
    let kerr = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            task_info(mach_task_self_, task_flavor_t(TASK_BASIC_INFO), $0, &count)
        }
    }
    
    return kerr == KERN_SUCCESS ? Int(info.resident_size) : 0
}
```

### Load Testing

```swift
@Test("Load test with multiple clients")
func testLoadHandling() async throws {
    let clientCount = 50
    let requestsPerClient = 10
    
    let clients = (0..<clientCount).map { _ in
        NetworkClient {
            BaseURL("https://httpbin.org")
            Session {
                MaxConnectionsPerHost(10)
            }
        }
    }
    
    let startTime = CFAbsoluteTimeGetCurrent()
    var successCount = 0
    var errorCount = 0
    
    try await withThrowingTaskGroup(of: Void.self) { group in
        for client in clients {
            group.addTask {
                for i in 0..<requestsPerClient {
                    do {
                        let response = try await client.execute {
                            GET("/get")
                            QueryParam("client", "test")
                            QueryParam("request", "\(i)")
                        }
                        
                        if response.status.isSuccess {
                            successCount += 1
                        } else {
                            errorCount += 1
                        }
                    } catch {
                        errorCount += 1
                    }
                }
            }
        }
        
        for try await _ in group {
            // All tasks completed
        }
    }
    
    let endTime = CFAbsoluteTimeGetCurrent()
    let duration = endTime - startTime
    let totalRequests = clientCount * requestsPerClient
    
    print("Completed \(totalRequests) requests in \(duration) seconds")
    print("Success rate: \(Double(successCount) / Double(totalRequests) * 100)%")
    
    // Expect reasonable success rate
    #expect(Double(successCount) / Double(totalRequests) >= 0.95) // 95% success rate
}
```

---

## Middleware Testing

### Testing Custom Middleware

```swift
@Test("Custom authentication middleware")
func testAuthenticationMiddleware() async throws {
    var tokenRefreshCount = 0
    
    let tokenProvider = MockTokenProvider(
        getCurrentToken: { "initial-token" },
        refreshToken: {
            tokenRefreshCount += 1
            return "refreshed-token"
        }
    )
    
    let mockClient = MockHTTPClient { request in
        if request.headers["Authorization"] == "Bearer initial-token" {
            // Simulate expired token
            throw HTTPError(category: .http(.unauthorized))
        } else if request.headers["Authorization"] == "Bearer refreshed-token" {
            // Return success
            return HTTPResponse(
                request: request,
                status: .ok,
                body: #"{"success": true}"#.data(using: .utf8)
            )
        } else {
            throw HTTPError(category: .http(.unauthorized))
        }
    }
    
    let authMiddleware = AuthenticationMiddleware(
        configuration: AuthenticationMiddleware.Configuration(),
        tokenProvider: tokenProvider,
        client: mockClient
    )
    
    let client = NetworkClient(
        errorMiddlewares: [authMiddleware]
    )
    
    let request = HTTPRequest(
        method: .get,
        url: URL(string: "https://api.example.com/protected")!,
        headers: ["Authorization": "Bearer initial-token"]
    )
    
    // Should succeed after token refresh
    let response = try await client.execute(request)
    
    #expect(response.status == .ok)
    #expect(tokenRefreshCount == 1)
}

@Test("Retry middleware with exponential backoff")
func testRetryMiddleware() async throws {
    var attemptCount = 0
    var attemptTimes: [Date] = []
    
    let mockClient = MockHTTPClient { request in
        attemptCount += 1
        attemptTimes.append(Date())
        
        if attemptCount < 3 {
            throw HTTPError(category: .network(.serverUnreachable))
        } else {
            return HTTPResponse(
                request: request,
                status: .ok,
                body: #"{"success": true}"#.data(using: .utf8)
            )
        }
    }
    
    let retryMiddleware = RetryMiddleware(
        configuration: RetryMiddleware.Configuration(
            maxAttempts: 3,
            baseDelay: 0.1,
            backoffMultiplier: 2.0
        ),
        client: mockClient
    )
    
    let client = NetworkClient(
        errorMiddlewares: [retryMiddleware]
    )
    
    let request = HTTPRequest(
        method: .get,
        url: URL(string: "https://api.example.com/test")!
    )
    
    let startTime = Date()
    let response = try await client.execute(request)
    let endTime = Date()
    
    #expect(response.status == .ok)
    #expect(attemptCount == 3)
    
    // Verify exponential backoff timing
    #expect(attemptTimes.count == 3)
    let duration = endTime.timeIntervalSince(startTime)
    #expect(duration >= 0.3) // 0.1 + 0.2 delays
}

@Test("Circuit breaker middleware")
func testCircuitBreakerMiddleware() async throws {
    var requestCount = 0
    
    let mockClient = MockHTTPClient { request in
        requestCount += 1
        throw HTTPError(category: .network(.serverUnreachable))
    }
    
    let circuitBreaker = CircuitBreakerMiddleware(
        configuration: CircuitBreakerMiddleware.Configuration(
            failureThreshold: 3,
            recoveryTimeout: 1.0
        ),
        client: mockClient
    )
    
    let client = NetworkClient(
        errorMiddlewares: [circuitBreaker]
    )
    
    let request = HTTPRequest(
        method: .get,
        url: URL(string: "https://api.example.com/test")!
    )
    
    // First 3 requests should reach the mock client
    for _ in 0..<3 {
        do {
            _ = try await client.execute(request)
        } catch {
            // Expected to fail
        }
    }
    
    #expect(requestCount == 3)
    
    // Next request should be blocked by circuit breaker
    do {
        _ = try await client.execute(request)
        #expect(Bool(false), "Expected circuit breaker to block request")
    } catch let error as CircuitBreakerError {
        #expect(error == .circuitOpen)
    }
    
    // Request count should still be 3
    #expect(requestCount == 3)
}
```

---

## End-to-End Testing

### Real API Testing

```swift
@Suite("End-to-End API Tests")
struct EndToEndTests {
    
    @Test("Complete user workflow", .tags(.e2e, .integration))
    func testCompleteUserWorkflow() async throws {
        guard let testToken = ProcessInfo.processInfo.environment["TEST_API_TOKEN"] else {
            throw XCTSkip("TEST_API_TOKEN not provided")
        }
        
        let client = NetworkClient {
            BaseURL("https://api.github.com")
            DefaultHeader("Accept", "application/vnd.github.v3+json")
            DefaultHeader("User-Agent", "ModernNetworking-Tests/1.0")
            
            Authentication {
                BearerToken(testToken)
            }
            
            Retry {
                MaxAttempts(3)
                RetryWhen.networkErrors()
            }
            
            EnableLogging()
        }
        
        // Step 1: Get authenticated user
        let userResponse = try await client.execute {
            GET("/user")
        }
        
        let user = try userResponse.decode(GitHubUser.self)
        #expect(!user.login.isEmpty)
        
        // Step 2: Get user's repositories
        let reposResponse = try await client.execute {
            GET("/user/repos")
            QueryParam("type", "owner")
            QueryParam("sort", "updated")
            QueryParam("per_page", "10")
        }
        
        let repos = try reposResponse.decode([GitHubRepo].self)
        #expect(repos.count <= 10)
        
        // Step 3: Get details for first repository (if any)
        if let firstRepo = repos.first {
            let repoResponse = try await client.execute {
                GET("/repos/\(user.login)/\(firstRepo.name)")
            }
            
            let repoDetails = try repoResponse.decode(GitHubRepo.self)
            #expect(repoDetails.name == firstRepo.name)
            #expect(repoDetails.owner.login == user.login)
        }
    }
    
    @Test("Error handling end-to-end", .tags(.e2e, .errorHandling))
    func testErrorHandlingEndToEnd() async throws {
        let client = NetworkClient {
            BaseURL("https://api.github.com")
            DefaultHeader("Accept", "application/vnd.github.v3+json")
            
            // No authentication - should get 401 for protected resources
            Retry {
                MaxAttempts(2)
                RetryWhen { error, attempt in
                    // Don't retry auth errors
                    if case .http(let status) = error.category {
                        return status.rawValue != 401
                    }
                    return true
                }
            }
        }
        
        // Try to access protected resource without auth
        do {
            _ = try await client.execute {
                GET("/user")
            }
            #expect(Bool(false), "Expected authentication error")
        } catch let error as HTTPError {
            #expect(error.category == .http(.unauthorized))
            #expect(!error.isRetryable) // Auth errors shouldn't be retried
        }
        
        // Try to access non-existent resource
        do {
            _ = try await client.execute {
                GET("/nonexistent-endpoint-12345")
            }
            #expect(Bool(false), "Expected not found error")
        } catch let error as HTTPError {
            #expect(error.category == .http(.notFound))
        }
    }
}

struct GitHubUser: Codable {
    let login: String
    let id: Int
    let name: String?
    let email: String?
}

struct GitHubRepo: Codable {
    let name: String
    let fullName: String
    let owner: GitHubUser
    let description: String?
    let language: String?
    let stargazersCount: Int
    
    enum CodingKeys: String, CodingKey {
        case name
        case fullName = "full_name"
        case owner
        case description
        case language
        case stargazersCount = "stargazers_count"
    }
}
```

---

## Best Practices

### Test Organization

1. **Separate test types**:
   - Unit tests for individual components
   - Integration tests for component interactions
   - End-to-end tests for complete workflows

2. **Use descriptive test names**:
   ```swift
   @Test("NetworkClient should retry network errors with exponential backoff")
   func testNetworkErrorRetryWithExponentialBackoff() async throws {
       // Test implementation
   }
   ```

3. **Group related tests in suites**:
   ```swift
   @Suite("Authentication Tests")
   struct AuthenticationTests {
       // All auth-related tests
   }
   ```

### Test Data Management

1. **Use factories for test data**:
   ```swift
   let testUser = TestDataGenerator.randomUser()
   let testUsers = TestDataGenerator.randomUsers(count: 5)
   ```

2. **Keep test data minimal**:
   - Only include fields needed for the test
   - Use random data to avoid coupling

3. **Use environment variables for configuration**:
   ```swift
   guard let apiKey = ProcessInfo.processInfo.environment["TEST_API_KEY"] else {
       throw XCTSkip("TEST_API_KEY not provided")
   }
   ```

### Mock Strategy

1. **Mock at the right level**:
   - Mock `HTTPClient` for unit tests
   - Use `MockURLSession` for integration tests
   - Use real endpoints for E2E tests

2. **Make mocks realistic**:
   - Include appropriate delays
   - Return realistic response sizes
   - Simulate error conditions

3. **Verify interactions**:
   ```swift
   var capturedRequests: [HTTPRequest] = []
   let mockClient = MockHTTPClient { request in
       capturedRequests.append(request)
       return mockResponse
   }
   
   // After test execution
   #expect(capturedRequests.count == expectedCount)
   ```

### Async Testing

1. **Use async/await consistently**:
   ```swift
   @Test("Async operation completes successfully")
   func testAsyncOperation() async throws {
       let result = try await performAsyncOperation()
       #expect(result.isSuccess)
   }
   ```

2. **Test cancellation behavior**:
   ```swift
   @Test("Request can be cancelled")
   func testRequestCancellation() async throws {
       let task = Task {
           try await client.execute(longRunningRequest)
       }
       
       task.cancel()
       
       do {
           _ = try await task.value
           #expect(Bool(false), "Expected cancellation error")
       } catch is CancellationError {
           // Expected
       }
   }
   ```

3. **Test timeout behavior**:
   ```swift
   @Test("Request times out appropriately")
   func testRequestTimeout() async throws {
       let client = NetworkClient()
       
       do {
           _ = try await client.execute {
               GET("/delay/10") // 10 second delay
               Timeout(2.0)     // 2 second timeout
           }
           #expect(Bool(false), "Expected timeout error")
       } catch let error as HTTPError {
           #expect(error.category == .timeout)
       }
   }
   ```

### Performance Testing

1. **Set realistic expectations**:
   - Account for network variability
   - Test under different conditions
   - Use appropriate timeouts

2. **Test resource usage**:
   - Memory consumption
   - Connection pooling
   - Concurrent request handling

3. **Profile critical paths**:
   - Request serialization
   - Response deserialization
   - Middleware execution

This comprehensive testing guide provides the foundation for thoroughly testing ModernNetworking-based applications, ensuring reliability and maintainability in production environments.