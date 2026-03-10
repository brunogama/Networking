@testable import NetworkingInterceptorsCompat
import NetworkingRuntime
import NetworkingDSL
import NetworkingTesting
import XCTest

// swiftlint:disable file_length

final class ResponseInterceptorTests: XCTestCase {  // swiftlint:disable:this type_body_length
  // MARK: - Test Actor for Mutable State

  actor TestState<T> {
    var value: T?

    func set(_ newValue: T) {
      value = newValue
    }

    func get() -> T? {
      value
    }
  }

  // MARK: - Mock Interceptors

  struct StatusCodeInspector: ResponseInterceptor {
    let onStatusCode: @Sendable (Int) -> Void

    func intercept(
      response: HTTPResponse,
      context _: InterceptorContext
    ) async throws -> InterceptorResult {
      onStatusCode(response.status.rawValue.rawValue)
      return .proceed
    }
  }

  struct RetryOn401Interceptor: ResponseInterceptor {
    func intercept(
      response: HTTPResponse,
      context _: InterceptorContext
    ) async throws -> InterceptorResult {
      if response.status.rawValue == 401 {
        return .retry(after: nil)
      }
      return .proceed
    }
  }

  struct RetryWithBackoffInterceptor: ResponseInterceptor {
    let maxAttempts: Int

    func intercept(
      response: HTTPResponse,
      context: InterceptorContext
    ) async throws -> InterceptorResult {
      guard response.status.rawValue >= 500 else {
        return .proceed
      }

      guard context.attemptCount.rawValue < maxAttempts else {
        return .proceed
      }

      let delay = pow(2.0, Double(context.attemptCount.rawValue))
      return .retry(after: RetryDelay(delay))
    }
  }

  struct CacheSavingInterceptor: ResponseInterceptor {
    let onSave: @Sendable (HTTPResponse) -> Void

    func intercept(
      response: HTTPResponse,
      context _: InterceptorContext
    ) async throws -> InterceptorResult {
      if response.status.rawValue == 200 {
        onSave(response)
      }
      return .proceed
    }
  }

  struct ResponseReplacingInterceptor: ResponseInterceptor {
    let replacementResponse: HTTPResponse

    func intercept(
      response _: HTTPResponse,
      context _: InterceptorContext
    ) async throws -> InterceptorResult {
      return .shortCircuit(replacementResponse)
    }
  }

  // MARK: - Helper Methods

  func makeRequest() -> HTTPRequest {
    HTTPRequest(
      method: .get,
      url: URL(string: "https://api.example.com/users")!
    )
  }

  // swiftlint:disable:next cyclomatic_complexity
  func makeStatus(code: Int) -> HTTPStatus {
    // Work around Swift compiler/build system issue with HTTPStatus(rawValue:)
    // by using static properties when available
    switch code {
    case 100: return .continue
    case 101: return .switchingProtocols
    case 200: return .ok
    case 201: return .created
    case 202: return .accepted
    case 204: return .noContent
    case 300: return .multipleChoices
    case 301: return .movedPermanently
    case 302: return .found
    case 400: return .badRequest
    case 401: return .unauthorized
    case 403: return .forbidden
    case 404: return .notFound
    case 429: return .tooManyRequests
    case 500: return .internalServerError
    case 502: return .badGateway
    case 503: return .serviceUnavailable
    default: return HTTPStatus(rawValue: code)
    }
  }

  func makeResponse(statusCode: Int = 200, body: String? = nil) -> HTTPResponse {
    HTTPResponse(
      request: makeRequest(),
      status: makeStatus(code: statusCode),
      body: body.map { Data($0.utf8) }
    )
  }

  func makeContext(
    path: String = "/users",
    method: HTTPMethod = .get,
    attemptCount: Int = 0
  ) -> InterceptorContext {
    InterceptorContext(path: path, method: method, attemptCount: attemptCount)
  }

  // MARK: - Response Inspection Tests

  func testInterceptorCanInspectStatusCode() async throws {
    nonisolated(unsafe) var inspectedStatusCode: Int?

    let interceptor = StatusCodeInspector { statusCode in
      inspectedStatusCode = statusCode
    }

    let response = makeResponse(statusCode: 200)
    let context = makeContext()

    let result = try await interceptor.intercept(response: response, context: context)

    XCTAssertEqual(inspectedStatusCode, 200)

    if case .proceed = result {
      // Expected
    } else {
      XCTFail("Expected .proceed result")
    }
  }

  func testInterceptorCanInspectResponseBody() async throws {
    nonisolated(unsafe) var inspectedBody: String?

    struct BodyInspector: ResponseInterceptor {
      let onBody: @Sendable (String?) -> Void

      func intercept(
        response: HTTPResponse,
        context _: InterceptorContext
      ) async throws -> InterceptorResult {
        onBody(String(data: (response.body ?? HTTPBody(Data())).rawValue, encoding: .utf8))
        return .proceed
      }
    }

    let interceptor = BodyInspector { body in
      inspectedBody = body
    }

    let response = makeResponse(body: "test data")
    let context = makeContext()

    _ = try await interceptor.intercept(response: response, context: context)

    XCTAssertEqual(inspectedBody, "test data")
  }

  func testInterceptorCanInspectHeaders() async throws {
    nonisolated(unsafe) var inspectedHeaders: [String: String]?

    struct HeaderInspector: ResponseInterceptor {
      let onHeaders: @Sendable ([String: String]) -> Void

      func intercept(
        response: HTTPResponse,
        context _: InterceptorContext
      ) async throws -> InterceptorResult {
        onHeaders(response.headers.rawValue)
        return .proceed
      }
    }

    let interceptor = HeaderInspector { headers in
      inspectedHeaders = headers
    }

    let response = HTTPResponse(
      request: makeRequest(),
      status: HTTPStatus(rawValue: 200),
      headers: ["Content-Type": "application/json"],
      body: nil
    )
    let context = makeContext()

    _ = try await interceptor.intercept(response: response, context: context)

    XCTAssertEqual(inspectedHeaders?["Content-Type"], "application/json")
  }

  // MARK: - Retry Tests

  func testRetryOn401() async throws {
    let interceptor = RetryOn401Interceptor()

    let unauthorizedResponse = makeResponse(statusCode: 401)
    let context = makeContext()

    let result = try await interceptor.intercept(response: unauthorizedResponse, context: context)

    if case .retry(let delay) = result {
      XCTAssertNil(delay, "Should retry immediately without delay")
    } else {
      XCTFail("Expected .retry result for 401 response")
    }
  }

  func testProceedOnSuccess() async throws {
    let interceptor = RetryOn401Interceptor()

    let successResponse = makeResponse(statusCode: 200)
    let context = makeContext()

    let result = try await interceptor.intercept(response: successResponse, context: context)

    if case .proceed = result {
      // Expected
    } else {
      XCTFail("Expected .proceed result for 200 response")
    }
  }

  func testRetryWithExponentialBackoff() async throws {
    let interceptor = RetryWithBackoffInterceptor(maxAttempts: 3)

    let serverErrorResponse = makeResponse(statusCode: 500)

    // First attempt (attemptCount = 0)
    let context0 = makeContext(attemptCount: 0)
    let result0 = try await interceptor.intercept(response: serverErrorResponse, context: context0)

    if case .retry(let delay0) = result0 {
      XCTAssertEqual(delay0, RetryDelay(1.0))  // 2^0 = 1
    } else {
      XCTFail("Expected .retry with 1s delay for attempt 0")
    }

    // Second attempt (attemptCount = 1)
    let context1 = makeContext(attemptCount: 1)
    let result1 = try await interceptor.intercept(response: serverErrorResponse, context: context1)

    if case .retry(let delay1) = result1 {
      XCTAssertEqual(delay1, RetryDelay(2.0))  // 2^1 = 2
    } else {
      XCTFail("Expected .retry with 2s delay for attempt 1")
    }

    // Third attempt (attemptCount = 2)
    let context2 = makeContext(attemptCount: 2)
    let result2 = try await interceptor.intercept(response: serverErrorResponse, context: context2)

    if case .retry(let delay2) = result2 {
      XCTAssertEqual(delay2, RetryDelay(4.0))  // 2^2 = 4
    } else {
      XCTFail("Expected .retry with 4s delay for attempt 2")
    }
  }

  func testMaxAttemptsStopsRetry() async throws {
    let interceptor = RetryWithBackoffInterceptor(maxAttempts: 3)

    let serverErrorResponse = makeResponse(statusCode: 500)

    // Attempt 3 (max attempts reached)
    let context = makeContext(attemptCount: 3)
    let result = try await interceptor.intercept(response: serverErrorResponse, context: context)

    if case .proceed = result {
      // Expected - max attempts reached, stop retrying
    } else {
      XCTFail("Expected .proceed when max attempts reached")
    }
  }

  // MARK: - Caching Tests

  func testCacheSavingOn200() async throws {
    nonisolated(unsafe) var savedResponse: HTTPResponse?

    let interceptor = CacheSavingInterceptor { response in
      savedResponse = response
    }

    let successResponse = makeResponse(statusCode: 200, body: "data to cache")
    let context = makeContext()

    _ = try await interceptor.intercept(response: successResponse, context: context)

    XCTAssertNotNil(savedResponse)
    XCTAssertEqual(savedResponse?.status.rawValue.rawValue, 200)
    XCTAssertEqual(
      String(data: (savedResponse?.body ?? HTTPBody(Data())).rawValue, encoding: .utf8),
      "data to cache"
    )
  }

  func testCacheNotSavedOnError() async throws {
    nonisolated(unsafe) var savedResponse: HTTPResponse?

    let interceptor = CacheSavingInterceptor { response in
      savedResponse = response
    }

    let errorResponse = makeResponse(statusCode: 500)
    let context = makeContext()

    _ = try await interceptor.intercept(response: errorResponse, context: context)

    XCTAssertNil(savedResponse, "Should not cache error responses")
  }

  // MARK: - Response Replacement Tests

  func testResponseReplacement() async throws {
    let replacementResponse = makeResponse(statusCode: 200, body: "replacement data")
    let interceptor = ResponseReplacingInterceptor(replacementResponse: replacementResponse)

    let originalResponse = makeResponse(statusCode: 404, body: "not found")
    let context = makeContext()

    let result = try await interceptor.intercept(response: originalResponse, context: context)

    if case .shortCircuit(let response) = result {
      XCTAssertEqual(response.status.rawValue.rawValue, 200)
      XCTAssertEqual(
        String(data: (response.body ?? HTTPBody(Data())).rawValue, encoding: .utf8),
        "replacement data"
      )
    } else {
      XCTFail("Expected .shortCircuit result")
    }
  }

  // MARK: - Context Usage Tests

  func testInterceptorReceivesAttemptCount() async throws {
    nonisolated(unsafe) var receivedAttemptCount: Int?

    struct AttemptCapturingInterceptor: ResponseInterceptor {
      let onAttempt: @Sendable (Int) -> Void

      func intercept(
        response _: HTTPResponse,
        context: InterceptorContext
      ) async throws -> InterceptorResult {
        onAttempt(context.attemptCount.rawValue)
        return .proceed
      }
    }

    let interceptor = AttemptCapturingInterceptor { count in
      receivedAttemptCount = count
    }

    let response = makeResponse()
    let context = makeContext(attemptCount: 5)

    _ = try await interceptor.intercept(response: response, context: context)

    XCTAssertEqual(receivedAttemptCount, 5)
  }

  func testInterceptorReceivesPath() async throws {
    nonisolated(unsafe) var receivedPath: String?

    struct PathCapturingInterceptor: ResponseInterceptor {
      let onPath: @Sendable (String) -> Void

      func intercept(
        response _: HTTPResponse,
        context: InterceptorContext
      ) async throws -> InterceptorResult {
        onPath(context.path.rawValue)
        return .proceed
      }
    }

    let interceptor = PathCapturingInterceptor { path in
      receivedPath = path
    }

    let response = makeResponse()
    let context = makeContext(path: "/api/users/123")

    _ = try await interceptor.intercept(response: response, context: context)

    XCTAssertEqual(receivedPath, "/api/users/123")
  }

  // MARK: - Metadata Tests

  func testInterceptorCanAccessMetadata() async throws {
    nonisolated(unsafe) var receivedMetadata: [InterceptorMetadataKey: AnySendable]?

    struct MetadataCapturingInterceptor: ResponseInterceptor {
      let onMetadata: @Sendable ([InterceptorMetadataKey: AnySendable]) -> Void

      func intercept(
        response _: HTTPResponse,
        context: InterceptorContext
      ) async throws -> InterceptorResult {
        onMetadata(context.metadata)
        return .proceed
      }
    }

    let interceptor = MetadataCapturingInterceptor { metadata in
      receivedMetadata = metadata
    }

    let response = makeResponse()
    let context = InterceptorContext(
      path: "/users",
      method: .get,
      attemptCount: 0,
      metadata: ["requestId": .string("abc123"), "priority": .int(5)]
    )

    _ = try await interceptor.intercept(response: response, context: context)

    XCTAssertEqual(
      receivedMetadata?[InterceptorMetadataKey("requestId")]?.stringValue?.rawValue,
      "abc123"
    )
    XCTAssertEqual(
      receivedMetadata?[InterceptorMetadataKey("priority")]?.intValue?.rawValue,
      5
    )
  }

  // MARK: - Sendable Compliance Tests

  func testInterceptorIsSendable() async throws {
    let interceptor = RetryOn401Interceptor()

    // This test verifies that the interceptor can be used in async context
    // Create test data outside the task group to avoid capturing self
    let response = makeResponse(statusCode: 200)
    let context = makeContext()

    await withTaskGroup(of: Void.self) { group in
      for _ in 0..<10 {
        group.addTask {
          _ = try? await interceptor.intercept(response: response, context: context)
        }
      }
    }
  }

  // MARK: - Combined Scenario Tests

  func testRetryAfterTokenRefreshScenario() async throws {
    // Simulates a token refresh interceptor that retries on 401
    struct TokenRefreshInterceptor: ResponseInterceptor {
      let onRefresh: @Sendable () async throws -> Void

      func intercept(
        response: HTTPResponse,
        context _: InterceptorContext
      ) async throws -> InterceptorResult {
        if response.status.rawValue == 401 {
          try await onRefresh()
          return .retry(after: nil)
        }
        return .proceed
      }
    }

    nonisolated(unsafe) var refreshCalled = false
    let interceptor = TokenRefreshInterceptor {
      refreshCalled = true
    }

    let unauthorizedResponse = makeResponse(statusCode: 401)
    let context = makeContext()

    let result = try await interceptor.intercept(response: unauthorizedResponse, context: context)

    XCTAssertTrue(refreshCalled, "Token refresh should have been called")

    if case .retry = result {
      // Expected
    } else {
      XCTFail("Expected .retry after token refresh")
    }
  }
}
