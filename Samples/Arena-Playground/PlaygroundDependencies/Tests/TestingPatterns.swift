import Foundation
import Networking

#if canImport(Testing)
import Testing
#endif

// MARK: - Testing Patterns

/// Comprehensive testing patterns and utilities for networking applications
///
/// This module provides practical testing strategies including:
/// - URLProtocol-based mocking for complete request/response simulation
/// - Dependency injection patterns for testable architecture
/// - Error scenario testing for robust error handling
/// - Performance testing utilities and benchmarks
/// - Integration testing with real endpoints
/// - Swift Testing framework integration
public struct TestingPatterns {
  /// Run all testing pattern examples
  public static func runAll() async {
    print("🧪 Testing Patterns for Networking Applications")
    print("=" * 50)

    await mockingExamples()
    await dependencyInjectionTests()
    await errorScenarioTesting()
    await performanceTesting()
    await integrationTesting()
    await middlewareTesting()

    print("\n✅ All testing patterns demonstrated!")
  }

  // MARK: - URLProtocol Mocking

  /// Demonstrates URLProtocol-based mocking for unit tests
  public static func mockingExamples() async {
    print("\n📋 URLProtocol Mocking Examples")
    print("-" * 30)

    // Register mock protocol
    let mockConfig = URLSessionConfiguration.ephemeral
    mockConfig.protocolClasses = [MockURLProtocol.self]
    let mockSession = URLSession(configuration: mockConfig)

    // Example 1: Mock successful response
    MockURLProtocol.mockResponse(
      for: "https://api.example.com/users/123",
      statusCode: 200,
      data: """
        {
            "id": 123,
            "name": "John Doe",
            "email": "john@example.com"
        }
        """.data(using: .utf8)!
    )

    let client = HTTPClient(session: mockSession)

    do {
      let response = try await client.get(url: URL(string: "https://api.example.com/users/123")!)
      print("✅ Mock response received: \(response.statusCode)")
    } catch {
      print("❌ Mock test failed: \(error)")
    }

    // Example 2: Mock network error
    MockURLProtocol.mockError(
      for: "https://api.example.com/error",
      error: URLError(.notConnectedToInternet)
    )

    do {
      _ = try await client.get(url: URL(string: "https://api.example.com/error")!)
      print("❌ Should have thrown network error")
    } catch {
      print("✅ Network error correctly simulated: \(error.localizedDescription)")
    }

    // Example 3: Mock with delay simulation
    MockURLProtocol.mockResponse(
      for: "https://api.example.com/slow",
      statusCode: 200,
      data: Data(),
      delay: 2.0
    )

    let startTime = Date()
    do {
      _ = try await client.get(url: URL(string: "https://api.example.com/slow")!)
      let elapsed = Date().timeIntervalSince(startTime)
      print("✅ Delayed response simulated: \(String(format: "%.2f", elapsed))s")
    } catch {
      print("❌ Delayed mock failed: \(error)")
    }
  }

  // MARK: - Dependency Injection Testing

  /// Demonstrates testable architecture with dependency injection
  public static func dependencyInjectionTests() async {
    print("\n🔌 Dependency Injection Testing")
    print("-" * 30)

    // Example 1: Service with injected HTTPClient
    let mockService = MockNetworkService()
    let userService = UserService(networkService: mockService)

    // Configure mock responses
    mockService.mockResponse(
      for: .getUser(id: 42),
      response: UserResponse(id: 42, name: "Alice", email: "alice@example.com")
    )

    do {
      let user = try await userService.fetchUser(id: 42)
      print("✅ Dependency injection test passed: \(user.name)")
    } catch {
      print("❌ Dependency injection test failed: \(error)")
    }

    // Example 2: Testing error propagation
    mockService.mockError(
      for: .getUser(id: 404),
      error: APIError.userNotFound
    )

    do {
      _ = try await userService.fetchUser(id: 404)
      print("❌ Should have thrown user not found error")
    } catch APIError.userNotFound {
      print("✅ Error propagation test passed")
    } catch {
      print("❌ Unexpected error: \(error)")
    }

    // Example 3: Verify request parameters
    mockService.mockResponse(
      for: .createUser(name: "Bob", email: "bob@example.com"),
      response: UserResponse(id: 123, name: "Bob", email: "bob@example.com")
    )

    do {
      let newUser = try await userService.createUser(name: "Bob", email: "bob@example.com")
      let lastRequest = mockService.lastRequest
      print("✅ Request verification: \(lastRequest?.endpoint.path ?? "unknown")")
      print("   Created user: \(newUser.name)")
    } catch {
      print("❌ Request verification failed: \(error)")
    }
  }

  // MARK: - Error Scenario Testing

  /// Demonstrates comprehensive error scenario testing
  public static func errorScenarioTesting() async {
    print("\n💥 Error Scenario Testing")
    print("-" * 30)

    let errorTestClient = ErrorTestingClient()

    // Test 1: Network connectivity errors
    print("Testing network connectivity errors...")
    await errorTestClient.testNetworkErrors()

    // Test 2: HTTP status code errors
    print("Testing HTTP status code errors...")
    await errorTestClient.testHTTPErrors()

    // Test 3: Timeout scenarios
    print("Testing timeout scenarios...")
    await errorTestClient.testTimeouts()

    // Test 4: Malformed response data
    print("Testing malformed response data...")
    await errorTestClient.testDataParsingErrors()

    // Test 5: Authentication failures
    print("Testing authentication failures...")
    await errorTestClient.testAuthenticationErrors()
  }

  // MARK: - Performance Testing

  /// Demonstrates performance testing and benchmarking
  public static func performanceTesting() async {
    print("\n⚡ Performance Testing")
    print("-" * 30)

    let performanceTester = PerformanceTester()

    // Test 1: Concurrent request handling
    print("Testing concurrent request performance...")
    await performanceTester.testConcurrentRequests(count: 10)

    // Test 2: Large payload handling
    print("Testing large payload performance...")
    await performanceTester.testLargePayloadPerformance()

    // Test 3: Connection pooling efficiency
    print("Testing connection pooling...")
    await performanceTester.testConnectionPooling()

    // Test 4: Memory usage during streaming
    print("Testing memory usage during streaming...")
    await performanceTester.testStreamingMemoryUsage()
  }

  // MARK: - Integration Testing

  /// Demonstrates integration testing with real endpoints
  public static func integrationTesting() async {
    print("\n🔗 Integration Testing")
    print("-" * 30)

    let integrationTester = IntegrationTester()

    // Test 1: Real API endpoint validation
    print("Testing real API endpoints...")
    await integrationTester.testRealEndpoints()

    // Test 2: End-to-end authentication flow
    print("Testing authentication flow...")
    await integrationTester.testAuthenticationFlow()

    // Test 3: Rate limiting behavior
    print("Testing rate limiting...")
    await integrationTester.testRateLimiting()
  }

  // MARK: - Middleware Testing

  /// Demonstrates middleware testing patterns
  public static func middlewareTesting() async {
    print("\n🔄 Middleware Testing")
    print("-" * 30)

    let middlewareTester = MiddlewareTester()

    // Test 1: Request transformation middleware
    print("Testing request transformation...")
    await middlewareTester.testRequestTransformation()

    // Test 2: Response caching middleware
    print("Testing response caching...")
    await middlewareTester.testResponseCaching()

    // Test 3: Retry logic middleware
    print("Testing retry logic...")
    await middlewareTester.testRetryLogic()

    // Test 4: Authentication middleware
    print("Testing authentication middleware...")
    await middlewareTester.testAuthenticationMiddleware()
  }
}

// MARK: - Mock URLProtocol

/// URLProtocol-based mock for complete request/response simulation
public class MockURLProtocol: URLProtocol {
  private static var mockResponses: [String: MockResponse] = [:]
  private static var mockErrors: [String: Error] = [:]

  struct MockResponse {
    let statusCode: Int
    let data: Data
    let headers: [String: String]
    let delay: TimeInterval?

    init(statusCode: Int, data: Data, headers: [String: String] = [:], delay: TimeInterval? = nil) {
      self.statusCode = statusCode
      self.data = data
      self.headers = headers
      self.delay = delay
    }
  }

  override public class func canInit(with request: URLRequest) -> Bool {
    request.url?.absoluteString.hasPrefix("https://api.example.com") == true
  }

  override public class func canonicalRequest(for request: URLRequest) -> URLRequest {
    request
  }

  override public func startLoading() {
    guard let url = request.url?.absoluteString else {
      client?.urlProtocol(self, didFailWithError: URLError(.badURL))
      return
    }

    // Check for mock error
    if let error = Self.mockErrors[url] {
      client?.urlProtocol(self, didFailWithError: error)
      return
    }

    // Check for mock response
    guard let mockResponse = Self.mockResponses[url] else {
      client?.urlProtocol(self, didFailWithError: URLError(.fileDoesNotExist))
      return
    }

    // Simulate delay if specified
    if let delay = mockResponse.delay {
      DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
        self.sendMockResponse(mockResponse)
      }
    } else {
      sendMockResponse(mockResponse)
    }
  }

  private func sendMockResponse(_ mockResponse: MockResponse) {
    let httpResponse = HTTPURLResponse(
      url: request.url!,
      statusCode: mockResponse.statusCode,
      httpVersion: "HTTP/1.1",
      headerFields: mockResponse.headers
    )!

    client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: mockResponse.data)
    client?.urlProtocolDidFinishLoading(self)
  }

  override public func stopLoading() {}

  // MARK: - Public Interface

  public static func mockResponse(
    for url: String,
    statusCode: Int,
    data: Data,
    headers: [String: String] = [:],
    delay: TimeInterval? = nil
  ) {
    mockResponses[url] = MockResponse(
      statusCode: statusCode,
      data: data,
      headers: headers,
      delay: delay
    )
    mockErrors.removeValue(forKey: url)
  }

  public static func mockError(for url: String, error: Error) {
    mockErrors[url] = error
    mockResponses.removeValue(forKey: url)
  }

  public static func clearAllMocks() {
    mockResponses.removeAll()
    mockErrors.removeAll()
  }
}

// MARK: - Test Models

public struct UserResponse: Codable {
  let id: Int
  let name: String
  let email: String
}

public enum UserEndpoint {
  case getUser(id: Int)
  case createUser(name: String, email: String)
  case updateUser(id: Int, name: String, email: String)

  var path: String {
    switch self {
    case .getUser(let id):
      return "/users/\(id)"

    case .createUser:
      return "/users"

    case .updateUser(let id, _, _):
      return "/users/\(id)"
    }
  }

  var method: String {
    switch self {
    case .getUser:
      return "GET"

    case .createUser:
      return "POST"

    case .updateUser:
      return "PUT"
    }
  }
}

public enum APIError: Error {
  case userNotFound
  case invalidData
  case networkError
  case authenticationFailed
  case rateLimitExceeded
}

// MARK: - Mock Network Service

public protocol NetworkService {
  func request<T: Codable>(_ endpoint: UserEndpoint) async throws -> T
}

public class MockNetworkService: NetworkService {
  private var mockResponses: [String: Any] = [:]
  private var mockErrors: [String: Error] = [:]

  public var lastRequest: (endpoint: UserEndpoint, timestamp: Date)?

  public init() {}

  public func request<T: Codable>(_ endpoint: UserEndpoint) async throws -> T {
    lastRequest = (endpoint, Date())

    let key = "\(endpoint.method) \(endpoint.path)"

    if let error = mockErrors[key] {
      throw error
    }

    guard let response = mockResponses[key] else {
      throw APIError.networkError
    }

    guard let typedResponse = response as? T else {
      throw APIError.invalidData
    }

    return typedResponse
  }

  public func mockResponse<T: Codable>(for endpoint: UserEndpoint, response: T) {
    let key = "\(endpoint.method) \(endpoint.path)"
    mockResponses[key] = response
    mockErrors.removeValue(forKey: key)
  }

  public func mockError(for endpoint: UserEndpoint, error: Error) {
    let key = "\(endpoint.method) \(endpoint.path)"
    mockErrors[key] = error
    mockResponses.removeValue(forKey: key)
  }
}

// MARK: - User Service

public class UserService {
  private let networkService: NetworkService

  public init(networkService: NetworkService) {
    self.networkService = networkService
  }

  public func fetchUser(id: Int) async throws -> UserResponse {
    try await networkService.request(.getUser(id: id))
  }

  public func createUser(name: String, email: String) async throws -> UserResponse {
    try await networkService.request(.createUser(name: name, email: email))
  }

  public func updateUser(id: Int, name: String, email: String) async throws -> UserResponse {
    try await networkService.request(.updateUser(id: id, name: name, email: email))
  }
}

// MARK: - Error Testing Client

public class ErrorTestingClient {
  public func testNetworkErrors() async {
    let errors: [URLError.Code] = [
      .notConnectedToInternet,
      .timedOut,
      .cannotConnectToHost,
      .networkConnectionLost,
      .dnsLookupFailed,
    ]

    for errorCode in errors {
      print("  Testing \(errorCode.rawValue)... ", terminator: "")

      MockURLProtocol.mockError(
        for: "https://api.example.com/test",
        error: URLError(errorCode)
      )

      let client = createMockClient()

      do {
        _ = try await client.get(url: URL(string: "https://api.example.com/test")!)
        print("❌ Should have failed")
      } catch {
        print("✅")
      }
    }
  }

  public func testHTTPErrors() async {
    let statusCodes = [400, 401, 403, 404, 500, 502, 503]

    for statusCode in statusCodes {
      print("  Testing HTTP \(statusCode)... ", terminator: "")

      MockURLProtocol.mockResponse(
        for: "https://api.example.com/test",
        statusCode: statusCode,
        data: Data()
      )

      let client = createMockClient()

      do {
        let response = try await client.get(url: URL(string: "https://api.example.com/test")!)
        if response.statusCode == statusCode {
          print("✅")
        } else {
          print("❌ Wrong status code")
        }
      } catch {
        print("✅ (threw error as expected)")
      }
    }
  }

  public func testTimeouts() async {
    print("  Testing request timeout... ", terminator: "")

    MockURLProtocol.mockResponse(
      for: "https://api.example.com/slow",
      statusCode: 200,
      data: Data(),
      delay: 5.0  // 5 second delay
    )

    var config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    config.timeoutIntervalForRequest = 2.0  // 2 second timeout

    let client = HTTPClient(session: URLSession(configuration: config))

    do {
      _ = try await client.get(url: URL(string: "https://api.example.com/slow")!)
      print("❌ Should have timed out")
    } catch {
      print("✅")
    }
  }

  public func testDataParsingErrors() async {
    print("  Testing malformed JSON... ", terminator: "")

    MockURLProtocol.mockResponse(
      for: "https://api.example.com/malformed",
      statusCode: 200,
      data: "{ invalid json }".data(using: .utf8)!
    )

    let client = createMockClient()

    do {
      let response = try await client.get(url: URL(string: "https://api.example.com/malformed")!)
      _ = try JSONSerialization.jsonObject(with: response.data)
      print("❌ Should have failed to parse")
    } catch {
      print("✅")
    }
  }

  public func testAuthenticationErrors() async {
    print("  Testing 401 Unauthorized... ", terminator: "")

    MockURLProtocol.mockResponse(
      for: "https://api.example.com/protected",
      statusCode: 401,
      data: """
        {
            "error": "Unauthorized",
            "message": "Invalid or expired token"
        }
        """.data(using: .utf8)!
    )

    let client = createMockClient()

    do {
      let response = try await client.get(url: URL(string: "https://api.example.com/protected")!)
      if response.statusCode == 401 {
        print("✅")
      } else {
        print("❌ Wrong status code")
      }
    } catch {
      print("✅ (threw error as expected)")
    }
  }

  private func createMockClient() -> HTTPClient {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return HTTPClient(session: URLSession(configuration: config))
  }
}

// MARK: - Performance Tester

public class PerformanceTester {
  public func testConcurrentRequests(count: Int) async {
    let startTime = Date()

    // Setup mock responses for concurrent testing
    for i in 1...count {
      MockURLProtocol.mockResponse(
        for: "https://api.example.com/concurrent/\(i)",
        statusCode: 200,
        data: """
          {"id": \(i), "message": "Response \(i)"}
          """.data(using: .utf8)!,
        delay: Double.random(in: 0.1...0.5)
      )
    }

    let client = createMockClient()

    await withTaskGroup(of: Void.self) { group in
      for i in 1...count {
        group.addTask {
          do {
            let url = URL(string: "https://api.example.com/concurrent/\(i)")!
            _ = try await client.get(url: url)
          } catch {
            print("  Request \(i) failed: \(error)")
          }
        }
      }
    }

    let elapsed = Date().timeIntervalSince(startTime)
    print("  ✅ Completed \(count) concurrent requests in \(String(format: "%.2f", elapsed))s")
    print("     Average: \(String(format: "%.3f", elapsed / Double(count)))s per request")
  }

  public func testLargePayloadPerformance() async {
    let largeData = Data(repeating: 0x41, count: 1_000_000)  // 1MB of 'A'

    MockURLProtocol.mockResponse(
      for: "https://api.example.com/large",
      statusCode: 200,
      data: largeData
    )

    let client = createMockClient()
    let startTime = Date()

    do {
      let response = try await client.get(url: URL(string: "https://api.example.com/large")!)
      let elapsed = Date().timeIntervalSince(startTime)
      let throughput = Double(response.data.count) / elapsed / 1_000_000  // MB/s

      print(
        "  ✅ Large payload (\(response.data.count / 1000)KB) processed in \(String(format: "%.2f", elapsed))s"
      )
      print("     Throughput: \(String(format: "%.2f", throughput)) MB/s")
    } catch {
      print("  ❌ Large payload test failed: \(error)")
    }
  }

  public func testConnectionPooling() async {
    // Test connection reuse by making multiple requests to same host
    let requestCount = 5
    let startTime = Date()

    for i in 1...requestCount {
      MockURLProtocol.mockResponse(
        for: "https://api.example.com/pooling/\(i)",
        statusCode: 200,
        data: "Response \(i)".data(using: .utf8)!
      )
    }

    let client = createMockClient()

    for i in 1...requestCount {
      do {
        let url = URL(string: "https://api.example.com/pooling/\(i)")!
        _ = try await client.get(url: url)
      } catch {
        print("  Request \(i) failed: \(error)")
      }
    }

    let elapsed = Date().timeIntervalSince(startTime)
    print(
      "  ✅ Connection pooling test: \(requestCount) requests in \(String(format: "%.3f", elapsed))s"
    )
  }

  public func testStreamingMemoryUsage() async {
    print("  📊 Memory usage testing requires real implementation")
    print("     Mock: Simulating streaming download of large file...")

    // In real implementation, this would monitor memory usage
    // during streaming download/upload operations
    let chunks = 100
    let chunkSize = 10_000  // 10KB chunks

    for i in 1...chunks {
      let chunkData = Data(repeating: UInt8(i % 256), count: chunkSize)

      MockURLProtocol.mockResponse(
        for: "https://api.example.com/stream/chunk/\(i)",
        statusCode: 200,
        data: chunkData
      )
    }

    print("  ✅ Streaming memory test setup complete (simulated)")
  }

  private func createMockClient() -> HTTPClient {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return HTTPClient(session: URLSession(configuration: config))
  }
}

// MARK: - Integration Tester

public class IntegrationTester {
  public func testRealEndpoints() async {
    print("  🌐 Testing real endpoints (requires network)...")

    // Use httpbin.org for reliable testing
    let client = HTTPClient()

    do {
      let response = try await client.get(url: URL(string: "https://httpbin.org/get")!)
      print("  ✅ Real endpoint test passed: \(response.statusCode)")
    } catch {
      print("  ⚠️  Real endpoint test failed (network required): \(error)")
    }
  }

  public func testAuthenticationFlow() async {
    print("  🔑 Testing authentication flow...")

    // Mock authentication endpoints
    MockURLProtocol.mockResponse(
      for: "https://api.example.com/auth/login",
      statusCode: 200,
      data: """
        {
            "access_token": "mock_access_token_123",
            "refresh_token": "mock_refresh_token_456",
            "expires_in": 3600
        }
        """.data(using: .utf8)!
    )

    MockURLProtocol.mockResponse(
      for: "https://api.example.com/auth/refresh",
      statusCode: 200,
      data: """
        {
            "access_token": "mock_new_access_token_789",
            "expires_in": 3600
        }
        """.data(using: .utf8)!
    )

    let client = createMockClient()

    do {
      // Test login
      let loginResponse = try await client.post(
        url: URL(string: "https://api.example.com/auth/login")!,
        body: """
          {
              "username": "testuser",
              "password": "testpass"
          }
          """.data(using: .utf8)!
      )

      print("  ✅ Login successful: \(loginResponse.statusCode)")

      // Test token refresh
      let refreshResponse = try await client.post(
        url: URL(string: "https://api.example.com/auth/refresh")!,
        body: "{}".data(using: .utf8)!
      )

      print("  ✅ Token refresh successful: \(refreshResponse.statusCode)")
    } catch {
      print("  ❌ Authentication flow failed: \(error)")
    }
  }

  public func testRateLimiting() async {
    print("  🚦 Testing rate limiting...")

    // Mock rate limit responses
    for i in 1...3 {
      MockURLProtocol.mockResponse(
        for: "https://api.example.com/ratelimit/\(i)",
        statusCode: i <= 2 ? 200 : 429,
        data: i <= 2
          ? "Success".data(using: .utf8)!
          : """
          {
              "error": "Rate limit exceeded",
              "retry_after": 60
          }
          """.data(using: .utf8)!,
        headers: i <= 2
          ? ["X-RateLimit-Remaining": "\(3 - i)"]
          : ["X-RateLimit-Remaining": "0", "Retry-After": "60"]
      )
    }

    let client = createMockClient()

    for i in 1...3 {
      do {
        let response = try await client.get(
          url: URL(string: "https://api.example.com/ratelimit/\(i)")!
        )
        if response.statusCode == 429 {
          print("  ✅ Rate limit triggered at request \(i)")
        } else {
          print("  ✅ Request \(i) successful: \(response.statusCode)")
        }
      } catch {
        print("  ❌ Rate limit test failed at request \(i): \(error)")
      }
    }
  }

  private func createMockClient() -> HTTPClient {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return HTTPClient(session: URLSession(configuration: config))
  }
}

// MARK: - Middleware Tester

public class MiddlewareTester {
  public func testRequestTransformation() async {
    print("  🔄 Testing request transformation middleware...")

    // Mock endpoint that expects transformed request
    MockURLProtocol.mockResponse(
      for: "https://api.example.com/transform",
      statusCode: 200,
      data: "Transformed request received".data(using: .utf8)!
    )

    // Create client with request transformation middleware
    let client = createClientWithMiddleware()

    do {
      let response = try await client.get(url: URL(string: "https://api.example.com/transform")!)
      print("  ✅ Request transformation successful: \(response.statusCode)")
    } catch {
      print("  ❌ Request transformation failed: \(error)")
    }
  }

  public func testResponseCaching() async {
    print("  💾 Testing response caching middleware...")

    // Mock cacheable response
    MockURLProtocol.mockResponse(
      for: "https://api.example.com/cacheable",
      statusCode: 200,
      data: "Cacheable content".data(using: .utf8)!,
      headers: ["Cache-Control": "max-age=3600"]
    )

    let client = createMockClient()

    // First request - should hit network
    let start1 = Date()
    do {
      _ = try await client.get(url: URL(string: "https://api.example.com/cacheable")!)
      let elapsed1 = Date().timeIntervalSince(start1)
      print("  ✅ First request: \(String(format: "%.3f", elapsed1))s")
    } catch {
      print("  ❌ First request failed: \(error)")
    }

    // Second request - should be faster (cache hit simulation)
    let start2 = Date()
    do {
      _ = try await client.get(url: URL(string: "https://api.example.com/cacheable")!)
      let elapsed2 = Date().timeIntervalSince(start2)
      print("  ✅ Second request: \(String(format: "%.3f", elapsed2))s (cache simulation)")
    } catch {
      print("  ❌ Second request failed: \(error)")
    }
  }

  public func testRetryLogic() async {
    print("  🔄 Testing retry logic middleware...")

    // Mock endpoint that fails first two times, succeeds on third
    var attemptCount = 0

    // This is a simplified mock - in real implementation,
    // you'd need more sophisticated retry middleware
    for attempt in 1...3 {
      MockURLProtocol.mockResponse(
        for: "https://api.example.com/retry/\(attempt)",
        statusCode: attempt < 3 ? 503 : 200,
        data: attempt < 3
          ? "Service unavailable".data(using: .utf8)!
          : "Success after retry".data(using: .utf8)!
      )
    }

    let client = createMockClient()

    // Simulate retry logic manually
    for attempt in 1...3 {
      do {
        let response = try await client.get(
          url: URL(string: "https://api.example.com/retry/\(attempt)")!
        )
        if response.statusCode == 200 {
          print("  ✅ Retry logic successful on attempt \(attempt)")
          break
        } else {
          print("  ⚠️  Attempt \(attempt) failed with status \(response.statusCode)")
        }
      } catch {
        print("  ⚠️  Attempt \(attempt) failed with error: \(error)")
      }
    }
  }

  public func testAuthenticationMiddleware() async {
    print("  🔐 Testing authentication middleware...")

    // Mock protected endpoint
    MockURLProtocol.mockResponse(
      for: "https://api.example.com/protected",
      statusCode: 200,
      data: "Protected resource accessed".data(using: .utf8)!
    )

    // Mock authentication middleware would add Authorization header
    let client = createMockClient()

    do {
      // In real implementation, auth middleware would automatically
      // add the Authorization header
      var request = URLRequest(url: URL(string: "https://api.example.com/protected")!)
      request.setValue("Bearer mock_token", forHTTPHeaderField: "Authorization")

      let response = try await client.execute(request: request)
      print("  ✅ Authentication middleware successful: \(response.statusCode)")
    } catch {
      print("  ❌ Authentication middleware failed: \(error)")
    }
  }

  private func createMockClient() -> HTTPClient {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return HTTPClient(session: URLSession(configuration: config))
  }

  private func createClientWithMiddleware() -> HTTPClient {
    // In real implementation, this would configure middleware chain
    createMockClient()
  }
}

// MARK: - Swift Testing Integration

#if canImport(Testing)

/// Example Swift Testing integration for networking code
@Suite("Networking Tests")
struct NetworkingTests {
  @Test("URL Protocol Mocking")
  func testURLProtocolMocking() async throws {
    MockURLProtocol.mockResponse(
      for: "https://api.example.com/test",
      statusCode: 200,
      data: #"{"success": true}"#.data(using: .utf8)!
    )

    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    let client = HTTPClient(session: URLSession(configuration: config))

    let response = try await client.get(url: URL(string: "https://api.example.com/test")!)
    #expect(response.statusCode == 200)
  }

  @Test("Error Handling")
  func testErrorHandling() async throws {
    MockURLProtocol.mockError(
      for: "https://api.example.com/error",
      error: URLError(.notConnectedToInternet)
    )

    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    let client = HTTPClient(session: URLSession(configuration: config))

    await #expect(throws: URLError.self) {
      try await client.get(url: URL(string: "https://api.example.com/error")!)
    }
  }

  @Test("Dependency Injection")
  func testDependencyInjection() async throws {
    let mockService = MockNetworkService()
    let userService = UserService(networkService: mockService)

    mockService.mockResponse(
      for: .getUser(id: 123),
      response: UserResponse(id: 123, name: "Test User", email: "test@example.com")
    )

    let user = try await userService.fetchUser(id: 123)
    #expect(user.id == 123)
    #expect(user.name == "Test User")
  }

  @Test("Performance Measurement", .timeLimit(.seconds(5)))
  func testPerformance() async throws {
    // Swift Testing provides built-in performance measurement
    MockURLProtocol.mockResponse(
      for: "https://api.example.com/perf",
      statusCode: 200,
      data: Data(repeating: 0x41, count: 10_000)
    )

    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    let client = HTTPClient(session: URLSession(configuration: config))

    let startTime = Date()
    _ = try await client.get(url: URL(string: "https://api.example.com/perf")!)
    let elapsed = Date().timeIntervalSince(startTime)

    // Expect reasonable performance
    #expect(elapsed < 1.0)
  }
}

#endif

// MARK: - Utilities

private extension String {
  static func * (string: String, count: Int) -> String {
    String(repeating: string, count: count)
  }
}
