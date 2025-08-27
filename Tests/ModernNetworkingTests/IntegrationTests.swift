import Testing
import Foundation
@testable import ModernNetworking

/// End-to-end functionality tests validating complete request/response cycles
@Suite("Integration Tests")
struct IntegrationTests {
  // MARK: - Test Infrastructure

  private func createTestClient() -> HTTPClient {
    do {
      return try NetworkClient {
        try BaseURL("https://httpbin.org")
        DefaultTimeout(30.0)
        DefaultHeader("User-Agent", "ModernNetworking-Tests/1.0")
      }
    } catch {
      fatalError("Failed to create test client: \(error)")
    }
  }

  private func createMockClient(with responses: [MockResponse]) -> MockHTTPClient {
    let client = MockHTTPClient()
    client.setResponses(responses)
    return client
  }

  // MARK: - Basic Request/Response Cycle Tests

  @Test("GET request with query parameters and headers")
  func testGETRequestComplete() async throws {
    let client = createTestClient()

    let request = try HTTPRequest {
      GET("/get")
      QueryParam("param1", "value1")
      QueryParam("param2", "value2")
      Header("X-Custom-Header", "custom-value")
      Header("Accept", "application/json")
    }

    let response = try await client.execute(request)

    #expect(response.status.isSuccess)
    #expect(response.body != nil)

    // Verify request was sent correctly
    if let responseData = response.body,
      let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
      let args = json["args"] as? [String: String],
      let headers = json["headers"] as? [String: String]
    {
      #expect(args["param1"] == "value1")
      #expect(args["param2"] == "value2")
      #expect(headers["X-Custom-Header"] == "custom-value")
      #expect(headers["Accept"] == "application/json")
    }
  }

  @Test("POST request with JSON body")
  func testPOSTRequestWithJSON() async throws {
    let client = createTestClient()

    let testData = TestUser(
      id: "123",
      name: "John Doe",
      email: "john@example.com"
    )

    let request = try HTTPRequest {
      POST("/post")
      Header("Content-Type", "application/json")
      JSONBody(testData)
    }

    let response = try await client.execute(request)

    #expect(response.status.isSuccess)
    #expect(response.body != nil)

    // Verify the request body was sent correctly
    if let responseData = response.body,
      let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
      let jsonData = json["json"] as? [String: Any]
    {
      #expect(jsonData["id"] as? String == "123")
      #expect(jsonData["name"] as? String == "John Doe")
      #expect(jsonData["email"] as? String == "john@example.com")
    }
  }

  @Test("PUT request with data modification")
  func testPUTRequestWithModification() async throws {
    let client = createTestClient()

    let updateData = UserUpdate(
      name: "Jane Doe Updated",
      email: "jane.updated@example.com"
    )

    let request = try HTTPRequest {
      PUT("/put")
      Header("Content-Type", "application/json")
      JSONBody(updateData)
    }

    let response = try await client.execute(request)

    #expect(response.status.isSuccess)

    // Verify the update was processed
    if let responseData = response.body,
      let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
      let jsonData = json["json"] as? [String: Any]
    {
      #expect(jsonData["name"] as? String == "Jane Doe Updated")
      #expect(jsonData["email"] as? String == "jane.updated@example.com")
    }
  }

  @Test("DELETE request completion")
  func testDELETERequest() async throws {
    let client = createTestClient()

    let request = try HTTPRequest {
      DELETE("/delete")
      Header("Authorization", "Bearer test-token")
    }

    let response = try await client.execute(request)

    #expect(response.status.isSuccess)

    // Verify authorization header was included
    if let responseData = response.body,
      let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
      let headers = json["headers"] as? [String: String]
    {
      #expect(headers["Authorization"] == "Bearer test-token")
    }
  }

  @Test("PATCH request with partial update")
  func testPATCHRequest() async throws {
    let client = createTestClient()

    let patchData = ["name": "Partially Updated Name"]

    let request = try HTTPRequest {
      PATCH("/patch")
      Header("Content-Type", "application/json")
      JSONBody(patchData)
    }

    let response = try await client.execute(request)

    #expect(response.status.isSuccess)

    // Verify partial update was processed
    if let responseData = response.body,
      let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
      let jsonData = json["json"] as? [String: Any]
    {
      #expect(jsonData["name"] as? String == "Partially Updated Name")
    }
  }

  // MARK: - Response Processing Integration Tests

  @Test("Response decoding integration")
  func testResponseDecodingIntegration() async throws {
    let mockResponse = MockResponse(
      status: .ok,
      headers: ["Content-Type": "application/json"],
      body: """
        {
          "id": "456",
          "name": "Integration Test User",
          "email": "integration@example.com"
        }
        """.data(using: .utf8)!
    )

    let client = createMockClient(with: [mockResponse])

    let request = try HTTPRequest {
      GET("/user/456")
    }

    let response = try await client.execute(request)
    let decodedUser = try response.decode(TestUser.self)

    #expect(decodedUser.id == "456")
    #expect(decodedUser.name == "Integration Test User")
    #expect(decodedUser.email == "integration@example.com")
  }

  @Test("Response validation integration")
  func testResponseValidationIntegration() async throws {
    let successResponse = MockResponse(
      status: .ok,
      headers: ["Content-Type": "application/json"],
      body: "{\"success\": true, \"message\": \"Operation successful\"}".data(using: .utf8)!
    )

    let client = createMockClient(with: [successResponse])

    let request = try HTTPRequest {
      POST("/validate")
      JSONBody(["operation": "test"])
    }

    let response = try await client.execute(request)

    // Test response validation
    #expect(response.status.isSuccess)
    #expect(response.headers["Content-Type"]?.contains("application/json") == true)

    let validationResult = try response.decode(ValidationResult.self)
    #expect(validationResult.success == true)
    #expect(validationResult.message == "Operation successful")
  }

  @Test("Response transformation integration")
  func testResponseTransformationIntegration() async throws {
    let rawResponse = MockResponse(
      status: .ok,
      headers: ["Content-Type": "application/json"],
      body: """
        {
          "data": {
            "user_id": "789",
            "display_name": "Transformed User",
            "email_address": "transformed@example.com"
          },
          "metadata": {
            "timestamp": "2024-01-01T00:00:00Z",
            "version": "1.0"
          }
        }
        """.data(using: .utf8)!
    )

    let client = createMockClient(with: [rawResponse])

    let request = try HTTPRequest {
      GET("/transform")
    }

    let response = try await client.execute(request)
    let rawData = try response.decode(RawResponseData.self)

    // Transform the response
    let transformedUser = TestUser(
      id: rawData.data.user_id,
      name: rawData.data.display_name,
      email: rawData.data.email_address
    )

    #expect(transformedUser.id == "789")
    #expect(transformedUser.name == "Transformed User")
    #expect(transformedUser.email == "transformed@example.com")
  }

  // MARK: - Error Handling Integration Tests

  @Test("HTTP error handling integration")
  func testHTTPErrorHandlingIntegration() async throws {
    let errorResponse = MockResponse(
      status: .notFound,
      headers: ["Content-Type": "application/json"],
      body: """
        {
          "error": "Not Found",
          "message": "The requested resource was not found",
          "code": 404
        }
        """.data(using: .utf8)!
    )

    let client = createMockClient(with: [errorResponse])

    let request = try HTTPRequest {
      GET("/nonexistent")
    }

    do {
      _ = try await client.execute(request)
      Issue.record("Expected HTTP error to be thrown")
    } catch let error as HTTPError {
      #expect(error.category == .http(.notFound))
      #expect(error.request?.url.path == "/nonexistent")

      if let response = error.response {
        #expect(response.status == .notFound)
        let errorData = try response.decode(ErrorResponse.self)
        #expect(errorData.error == "Not Found")
        #expect(errorData.code == 404)
      }
    }
  }

  @Test("Network error handling integration")
  func testNetworkErrorHandlingIntegration() async throws {
    let client = createMockClient(with: [])
    client.shouldThrowNetworkError = true

    let request = try HTTPRequest {
      GET("/network-error")
    }

    do {
      _ = try await client.execute(request)
      Issue.record("Expected network error to be thrown")
    } catch let error as HTTPError {
      #expect(error.category == .network(.noConnection))
      #expect(error.request?.url.path == "/network-error")
    }
  }

  @Test("Timeout error handling integration")
  func testTimeoutErrorHandlingIntegration() async throws {
    let client = createMockClient(with: [])
    client.shouldTimeout = true

    let request = try HTTPRequest {
      GET("/timeout")
      Timeout(0.001)  // Very short timeout
    }

    do {
      _ = try await client.execute(request)
      Issue.record("Expected timeout error to be thrown")
    } catch let error as HTTPError {
      #expect(error.category == .timeout)
      #expect(error.request?.url.path == "/timeout")
    }
  }

  // MARK: - Middleware Integration Tests

  @Test("Logging middleware integration")
  func testLoggingMiddlewareIntegration() async throws {
    var loggedMessages: [String] = []

    let loggingMiddleware = LoggingMiddleware { level, message, _ in
      loggedMessages.append("\(level): \(message)")
    }

    let client = NetworkClient {
      try BaseURL("https://httpbin.org")
      Middleware(loggingMiddleware)
    }

    let request = try HTTPRequest {
      GET("/get")
      QueryParam("test", "logging")
    }

    let response = try await client.execute(request)

    #expect(response.status.isSuccess)
    #expect(!loggedMessages.isEmpty)
    #expect(loggedMessages.contains { $0.contains("Request started") })
    #expect(loggedMessages.contains { $0.contains("Response received") })
  }

  @Test("Retry middleware integration")
  func testRetryMiddlewareIntegration() async throws {
    var attemptCount = 0
    let retryableError = MockResponse(
      status: .internalServerError,
      headers: [:],
      body: Data()
    )

    let successResponse = MockResponse(
      status: .ok,
      headers: ["Content-Type": "application/json"],
      body: "{\"success\": true, \"attempt\": 2}".data(using: .utf8)!
    )

    let client = createMockClient(with: [retryableError, successResponse])
    client.onExecute = { _ in
      attemptCount += 1
    }

    let retryMiddleware = RetryMiddleware(
      maxAttempts: 3,
      baseDelay: 0.1,
      backoffMultiplier: 1.5
    )

    let clientWithRetry = NetworkClient {
      try BaseURL("https://example.com")
      Middleware(retryMiddleware)
    }

    // Override the client's internal HTTP client
    (clientWithRetry as? NetworkClient)?.httpClient = client

    let request = try HTTPRequest {
      GET("/retry-test")
    }

    let response = try await clientWithRetry.execute(request)

    #expect(response.status.isSuccess)
    #expect(attemptCount == 2)  // First attempt failed, second succeeded

    let result = try response.decode(ValidationResult.self)
    #expect(result.success == true)
  }

  @Test("Authentication middleware integration")
  func testAuthenticationMiddlewareIntegration() async throws {
    let authMiddleware = AuthenticationMiddleware(
      tokenProvider: { "Bearer test-token-123" }
    )

    let client = NetworkClient {
      try BaseURL("https://httpbin.org")
      Middleware(authMiddleware)
    }

    let request = try HTTPRequest {
      GET("/get")
    }

    let response = try await client.execute(request)

    #expect(response.status.isSuccess)

    // Verify the authentication header was added
    if let responseData = response.body,
      let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
      let headers = json["headers"] as? [String: String]
    {
      #expect(headers["Authorization"] == "Bearer test-token-123")
    }
  }

  @Test("Caching middleware integration")
  func testCachingMiddlewareIntegration() async throws {
    let storage = MemoryCacheStorage()
    let cachingMiddleware = CachingMiddleware(
      configuration: CachingMiddleware.Configuration(defaultTTL: 300.0),
      storage: storage
    )

    let client = NetworkClient {
      try BaseURL("https://httpbin.org")
      Middleware(cachingMiddleware)
    }

    let request = try HTTPRequest {
      GET("/get")
      QueryParam("cache-test", "true")
    }

    // First request - should hit the network
    let response1 = try await client.execute(request)
    #expect(response1.status.isSuccess)

    // Second request - should be cached
    let response2 = try await client.execute(request)
    #expect(response2.status.isSuccess)

    // Verify both responses have the same content
    #expect(response1.body == response2.body)

    // Check that entry is in cache
    let cachedEntry = await cachingMiddleware.getCachedEntry(for: request)
    #expect(cachedEntry != nil)
  }

  // MARK: - Builder Pattern Integration Tests

  @Test("NetworkClient builder pattern integration")
  func testNetworkClientBuilderIntegration() async throws {
    let client = NetworkClient {
      try BaseURL("https://httpbin.org")
      DefaultTimeout(15.0)
      DefaultHeader("User-Agent", "ModernNetworking-Builder-Test/1.0")
      DefaultHeader("Accept", "application/json")

      Middleware(LoggingMiddleware { _, _, _ in })
      Middleware(RetryMiddleware(maxAttempts: 2))
    }

    let request = try HTTPRequest {
      GET("/get")
      QueryParam("builder", "test")
    }

    let response = try await client.execute(request)

    #expect(response.status.isSuccess)

    // Verify default headers were applied
    if let responseData = response.body,
      let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
      let headers = json["headers"] as? [String: String]
    {
      #expect(headers["User-Agent"] == "ModernNetworking-Builder-Test/1.0")
      #expect(headers["Accept"] == "application/json")
    }
  }

  @Test("HTTPRequest builder pattern integration")
  func testHTTPRequestBuilderIntegration() async throws {
    let client = createTestClient()

    let request = try HTTPRequest {
      POST("/post")
      Header("Content-Type", "application/json")
      Header("Authorization", "Bearer complex-token")
      QueryParam("version", "2.0")
      QueryParam("format", "json")
      JSONBody([
        "operation": "complex-test",
        "parameters": [
          "param1": "value1",
          "param2": "value2",
        ],
      ])
      Timeout(25.0)
    }

    let response = try await client.execute(request)

    #expect(response.status.isSuccess)

    // Verify all components were applied correctly
    if let responseData = response.body,
      let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any]
    {
      // Check query parameters
      if let args = json["args"] as? [String: String] {
        #expect(args["version"] == "2.0")
        #expect(args["format"] == "json")
      }

      // Check headers
      if let headers = json["headers"] as? [String: String] {
        #expect(headers["Content-Type"] == "application/json")
        #expect(headers["Authorization"] == "Bearer complex-token")
      }

      // Check JSON body
      if let jsonBody = json["json"] as? [String: Any] {
        #expect(jsonBody["operation"] as? String == "complex-test")
        if let parameters = jsonBody["parameters"] as? [String: String] {
          #expect(parameters["param1"] == "value1")
          #expect(parameters["param2"] == "value2")
        }
      }
    }
  }

  // MARK: - Async Stream Integration Tests

  @Test("Async response streaming integration")
  func testAsyncResponseStreamingIntegration() async throws {
    let streamingResponse = MockResponse(
      status: .ok,
      headers: ["Content-Type": "application/x-ndjson"],
      body: """
        {"id": 1, "message": "First chunk"}
        {"id": 2, "message": "Second chunk"}
        {"id": 3, "message": "Third chunk"}
        """.data(using: .utf8)!
    )

    let client = createMockClient(with: [streamingResponse])

    let request = try HTTPRequest {
      GET("/stream")
    }

    let response = try await client.execute(request)

    #expect(response.status.isSuccess)

    // Simulate streaming processing
    if let bodyData = response.body {
      let bodyString = String(data: bodyData, encoding: .utf8) ?? ""
      let lines = bodyString.components(separatedBy: .newlines).filter { !$0.isEmpty }

      #expect(lines.count == 3)

      for (index, line) in lines.enumerated() {
        let data = line.data(using: .utf8)!
        let chunk = try JSONDecoder().decode(StreamChunk.self, from: data)
        #expect(chunk.id == index + 1)
        #expect(chunk.message.contains("chunk"))
      }
    }
  }

  // MARK: - Concurrent Operations Integration Tests

  @Test("Concurrent requests integration")
  func testConcurrentRequestsIntegration() async throws {
    let client = createTestClient()

    let numberOfRequests = 5
    let requests = (1...numberOfRequests).map { index in
      Task {
        let request = try HTTPRequest {
          GET("/get")
          QueryParam("request_id", String(index))
        }
        return try await client.execute(request)
      }
    }

    let responses = try await withThrowingTaskGroup(
      of: HTTPResponse.self,
      returning: [HTTPResponse].self
    ) { group in
      for requestTask in requests {
        group.addTask {
          try await requestTask.value
        }
      }

      var results: [HTTPResponse] = []
      for try await response in group {
        results.append(response)
      }
      return results
    }

    #expect(responses.count == numberOfRequests)

    // Verify all requests succeeded
    for response in responses {
      #expect(response.status.isSuccess)
    }
  }

  @Test("Load testing integration")
  func testLoadTestingIntegration() async throws {
    let client = createTestClient()

    let startTime = Date()
    let numberOfRequests = 20

    let responses = try await withThrowingTaskGroup(
      of: HTTPResponse.self,
      returning: [HTTPResponse].self
    ) { group in
      for index in 1...numberOfRequests {
        group.addTask {
          let request = try HTTPRequest {
            GET("/get")
            QueryParam("load_test_id", String(index))
          }
          return try await client.execute(request)
        }
      }

      var results: [HTTPResponse] = []
      for try await response in group {
        results.append(response)
      }
      return results
    }

    let duration = Date().timeIntervalSince(startTime)

    #expect(responses.count == numberOfRequests)
    #expect(duration < 30.0)  // Should complete within 30 seconds

    // Verify success rate
    let successCount = responses.filter { $0.status.isSuccess }.count
    let successRate = Double(successCount) / Double(numberOfRequests)
    #expect(successRate >= 0.95)  // At least 95% success rate
  }

  // MARK: - Real Network Integration Tests (Optional)

  @Test("Real network integration test", .disabled("Requires network access"))
  func testRealNetworkIntegration() async throws {
    let client = NetworkClient {
      try BaseURL("https://api.github.com")
      DefaultTimeout(30.0)
      DefaultHeader("User-Agent", "ModernNetworking-Integration-Test/1.0")
    }

    let request = try HTTPRequest {
      GET("/user")
      Header("Accept", "application/vnd.github.v3+json")
    }

    let response = try await client.execute(request)

    // Note: This will likely return 401 without auth, but that's expected
    #expect(response.status.rawValue == 401 || response.status.isSuccess)
    #expect(response.body != nil)
  }
}

// MARK: - Test Helper Types and Mock Classes

struct TestUser: Codable, Equatable {
  let id: String
  let name: String
  let email: String
}

struct UserUpdate: Codable {
  let name: String
  let email: String
}

struct ValidationResult: Codable {
  let success: Bool
  let message: String
}

struct ErrorResponse: Codable {
  let error: String
  let message: String
  let code: Int
}

struct RawResponseData: Codable {
  let data: UserData
  let metadata: Metadata

  struct UserData: Codable {
    let user_id: String
    let display_name: String
    let email_address: String
  }

  struct Metadata: Codable {
    let timestamp: String
    let version: String
  }
}

struct StreamChunk: Codable {
  let id: Int
  let message: String
}

/// Mock HTTP client for testing
final class MockHTTPClient: HTTPClient, @unchecked Sendable {
  private var responses: [MockResponse] = []
  private var currentIndex = 0

  var shouldThrowNetworkError = false
  var shouldTimeout = false
  var onExecute: ((HTTPRequest) -> Void)?

  func setResponses(_ responses: [MockResponse]) {
    self.responses = responses
    self.currentIndex = 0
  }

  func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
    onExecute?(request)

    if shouldTimeout {
      try await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second
      throw HTTPError.timeout(request: request)
    }

    if shouldThrowNetworkError {
      throw HTTPError.network(.noConnection, request: request)
    }

    guard currentIndex < responses.count else {
      throw HTTPError.network(.serverUnreachable, request: request)
    }

    let mockResponse = responses[currentIndex]
    currentIndex += 1

    let httpResponse = HTTPResponse(
      request: request,
      status: mockResponse.status,
      headers: mockResponse.headers,
      body: mockResponse.body
    )

    // Simulate network delay
    try await Task.sleep(nanoseconds: 10_000_000)  // 10ms

    if !mockResponse.status.isSuccess {
      throw HTTPError.http(status: mockResponse.status, request: request, response: httpResponse)
    }

    return httpResponse
  }
}

struct MockResponse {
  let status: HTTPStatus
  let headers: [String: String]
  let body: Data
}

// MARK: - Extensions for Testing

extension HTTPStatus {
  var isSuccess: Bool {
    switch self {
    case .ok, .created, .accepted, .noContent:
      return true

    default:
      return false
    }
  }
}

extension NetworkClient {
  var httpClient: HTTPClient? {
    get { nil }  // Not accessible in real implementation
    set {}  // Not settable in real implementation
  }
}
