import Foundation
@testable import NetworkingInterceptorsCompat
import NetworkingRuntime
import NetworkingDSL
import NetworkingTesting
import XCTest

// swiftlint:disable file_length

/// Thread-safe log collector for testing using NSLock for synchronous access
final class LogCollector: @unchecked Sendable {
  private var messages: [String] = []
  private let lock = NSLock()

  func append(_ message: String) {
    lock.lock()
    defer { lock.unlock() }
    messages.append(message)
  }

  func getMessages() -> [String] {
    lock.lock()
    defer { lock.unlock() }
    return messages
  }

  func reset() {
    lock.lock()
    defer { lock.unlock() }
    messages.removeAll()
  }
}

/// Tests for LoggingInterceptor
final class LoggingInterceptorTests: XCTestCase {  // swiftlint:disable:this type_body_length
  // MARK: - Log Level Tests

  func testNoneLevelDoesNotLog() async throws {
    // Given: An interceptor with .none level
    let collector = LogCollector()
    let interceptor = LoggingInterceptor(level: .none) { message in
      collector.append(message)
    }

    // When: Intercepting a request and response
    var request = HTTPRequest(method: .get, path: "/test", baseURL: "https://api.com")
    let context = InterceptorContext(path: "/test", method: .get, metadata: [:])

    _ = try await interceptor.intercept(request: &request, context: context)

    let response = HTTPResponse(
      request: request,
      status: .ok,
      headers: [:],
      body: nil
    )
    _ = try await interceptor.intercept(response: response, context: context)

    // Then: No messages logged
    XCTAssertTrue(collector.getMessages().isEmpty)
  }

  func testBasicLevelLogsRequestAndResponse() async throws {
    // Given: An interceptor with .basic level
    let collector = LogCollector()
    let interceptor = LoggingInterceptor(level: .basic) { message in
      collector.append(message)
    }

    // When: Intercepting a request and response
    var request = HTTPRequest(method: .post, path: "/users", baseURL: "https://api.com")
    let context = InterceptorContext(path: "/users", method: .post, metadata: [:])

    _ = try await interceptor.intercept(request: &request, context: context)

    let response = HTTPResponse(
      request: request,
      status: .created,
      headers: [:],
      body: nil
    )
    _ = try await interceptor.intercept(response: response, context: context)

    // Then: Request and response logged
    let messages = collector.getMessages()
    XCTAssertEqual(messages.count, 2)
    XCTAssertTrue(messages[0].contains("[REQUEST] POST /users"))
    XCTAssertTrue(messages[1].contains("[RESPONSE] POST /users - 201"))
  }

  func testHeadersLevelIncludesHeaders() async throws {
    // Given: An interceptor with .headers level
    let collector = LogCollector()
    let interceptor = LoggingInterceptor(level: .headers) { message in
      collector.append(message)
    }

    // When: Intercepting a request with headers
    var request = HTTPRequest(method: .get, path: "/data", baseURL: "https://api.com")
    request.addHeader(name: "Content-Type", value: "application/json")
    request.addHeader(name: "Accept", value: "application/json")

    let context = InterceptorContext(path: "/data", method: .get, metadata: [:])

    _ = try await interceptor.intercept(request: &request, context: context)

    // Then: Headers are logged
    let messages = collector.getMessages()
    XCTAssertEqual(messages.count, 1)
    XCTAssertTrue(messages[0].contains("Headers:"))
    XCTAssertTrue(messages[0].contains("Content-Type"))
    XCTAssertTrue(messages[0].contains("application/json"))
  }

  func testVerboseLevelIncludesBodySize() async throws {
    // Given: An interceptor with .verbose level
    let collector = LogCollector()
    let interceptor = LoggingInterceptor(level: .verbose) { message in
      collector.append(message)
    }

    // When: Intercepting a request with body
    var request = HTTPRequest(method: .post, path: "/upload", baseURL: "https://api.com")
    let bodyData = Data(repeating: 0, count: 1234)
    request.setBody(HTTPBody(bodyData))

    let context = InterceptorContext(path: "/upload", method: .post, metadata: [:])

    _ = try await interceptor.intercept(request: &request, context: context)

    // Then: Body size is logged
    let messages = collector.getMessages()
    XCTAssertEqual(messages.count, 1)
    XCTAssertTrue(messages[0].contains("Body: 1234 bytes"))
  }

  // MARK: - Error Logging

  func testErrorLevelOnlyLogsErrors() async throws {
    // Given: An interceptor with .error level
    let collector = LogCollector()
    let interceptor = LoggingInterceptor(level: .error) { message in
      collector.append(message)
    }

    let request = HTTPRequest(method: .get, path: "/test", baseURL: "https://api.com")
    let context = InterceptorContext(path: "/test", method: .get, metadata: [:])

    // When: Intercepting successful response
    let successResponse = HTTPResponse(
      request: request,
      status: .ok,
      headers: [:],
      body: nil
    )
    _ = try await interceptor.intercept(response: successResponse, context: context)

    // Then: No log for success
    XCTAssertTrue(collector.getMessages().isEmpty)

    // When: Intercepting error response
    let errorResponse = HTTPResponse(
      request: request,
      status: .notFound,
      headers: [:],
      body: nil
    )
    _ = try await interceptor.intercept(response: errorResponse, context: context)

    // Then: Error is logged
    let messages = collector.getMessages()
    XCTAssertEqual(messages.count, 1)
    XCTAssertTrue(messages[0].contains("404"))
    XCTAssertTrue(messages[0].contains("❌"))
  }

  func testErrorIndicatorFor4xxAnd5xx() async throws {
    // Given: An interceptor with basic level
    let collector = LogCollector()
    let interceptor = LoggingInterceptor(level: .basic) { message in
      collector.append(message)
    }

    let request = HTTPRequest(method: .get, path: "/test", baseURL: "https://api.com")
    let context = InterceptorContext(path: "/test", method: .get, metadata: [:])

    // When: Logging 4xx error
    let clientError = HTTPResponse(
      request: request,
      status: .badRequest,
      headers: [:],
      body: nil
    )
    _ = try await interceptor.intercept(response: clientError, context: context)

    // When: Logging 5xx error
    let serverError = HTTPResponse(
      request: request,
      status: .internalServerError,
      headers: [:],
      body: nil
    )
    _ = try await interceptor.intercept(response: serverError, context: context)

    // Then: Both have error indicator
    let messages = collector.getMessages()
    XCTAssertEqual(messages.count, 2)
    XCTAssertTrue(messages[0].contains("❌"))
    XCTAssertTrue(messages[1].contains("❌"))
  }

  // MARK: - Sensitive Header Redaction

  func testRedactsSensitiveHeaders() async throws {
    // Given: An interceptor with headers level
    let collector = LogCollector()
    let interceptor = LoggingInterceptor(level: .headers) { message in
      collector.append(message)
    }

    // When: Intercepting request with sensitive headers
    var request = HTTPRequest(method: .get, path: "/secure", baseURL: "https://api.com")
    request.addHeader(name: "Authorization", value: "Bearer secret-token")
    request.addHeader(name: "Api-Key", value: "secret-key-123")
    request.addHeader(name: "Content-Type", value: "application/json")

    let context = InterceptorContext(path: "/secure", method: .get, metadata: [:])

    _ = try await interceptor.intercept(request: &request, context: context)

    // Then: Sensitive headers are redacted
    let messages = collector.getMessages()
    XCTAssertEqual(messages.count, 1)
    XCTAssertTrue(messages[0].contains("[REDACTED]"))
    XCTAssertFalse(messages[0].contains("secret-token"))
    XCTAssertFalse(messages[0].contains("secret-key-123"))
    XCTAssertTrue(messages[0].contains("application/json"))  // Non-sensitive header preserved
  }

  func testRedactsAuthorizationCookieAndApiKeys() async throws {
    // Given: Response with sensitive headers
    let collector = LogCollector()
    let interceptor = LoggingInterceptor(level: .headers) { message in
      collector.append(message)
    }

    let request = HTTPRequest(method: .get, path: "/test", baseURL: "https://api.com")
    let context = InterceptorContext(path: "/test", method: .get, metadata: [:])

    let response = HTTPResponse(
      request: request,
      status: .ok,
      headers: [
        "Authorization": "Bearer token",
        "Cookie": "session=abc123",
        "X-API-Key": "key-value",
        "Content-Type": "text/html",
      ],
      body: nil
    )

    // When: Logging response
    _ = try await interceptor.intercept(response: response, context: context)

    // Then: All sensitive headers redacted
    let messages = collector.getMessages()
    XCTAssertEqual(messages.count, 1)
    let log = messages[0]
    XCTAssertTrue(log.contains("[REDACTED]"))
    XCTAssertFalse(log.contains("token"))
    XCTAssertFalse(log.contains("abc123"))
    XCTAssertFalse(log.contains("key-value"))
    XCTAssertTrue(log.contains("text/html"))
  }

  // MARK: - Convenience Constructors

  func testConvenienceConstructors() {
    let errorOnly = LoggingInterceptor.errorsOnly
    XCTAssertEqual(errorOnly.level, .error)

    let basic = LoggingInterceptor.basic
    XCTAssertEqual(basic.level, .basic)

    let withHeaders = LoggingInterceptor.withHeaders
    XCTAssertEqual(withHeaders.level, .headers)

    let verbose = LoggingInterceptor.verbose
    XCTAssertEqual(verbose.level, .verbose)
  }

  // MARK: - Integration with InterceptorChain

  func testLoggingInInterceptorChain() async throws {
    // Given: A chain with logging interceptor
    let collector = LogCollector()
    let logger = LoggingInterceptor(level: .basic) { message in
      collector.append(message)
    }

    let chain = InterceptorChain(
      requestInterceptors: [logger],
      responseInterceptors: [logger]
    )

    // When: Executing interceptor chain
    var request = HTTPRequest(method: .get, path: "/api/data", baseURL: "https://example.com")
    let context = InterceptorContext(path: "/api/data", method: .get, metadata: [:])

    _ = try await chain.executeRequestInterceptors(request: &request, context: context)

    let response = HTTPResponse(
      request: request,
      status: .ok,
      headers: [:],
      body: nil
    )

    _ = try await chain.executeResponseInterceptors(response: response, context: context)

    // Then: Both request and response are logged
    let messages = collector.getMessages()
    let requestLogs = messages.filter { $0.contains("[REQUEST]") }
    let responseLogs = messages.filter { $0.contains("[RESPONSE]") }

    XCTAssertEqual(requestLogs.count, 1)
    XCTAssertEqual(responseLogs.count, 1)
    XCTAssertTrue(requestLogs[0].contains("GET /api/data"))
    XCTAssertTrue(responseLogs[0].contains("200"))
  }
}
