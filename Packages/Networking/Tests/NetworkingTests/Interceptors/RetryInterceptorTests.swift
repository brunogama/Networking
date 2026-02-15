import Foundation
import XCTest

@testable import Networking

/// Tests for RetryInterceptor
final class RetryInterceptorTests: XCTestCase {
  // MARK: - Retryable Errors

  func testRetriesServerErrors() async throws {
    // Given: A retry interceptor
    let interceptor = RetryInterceptor(maxAttempts: 3, baseDelay: 0.1)

    // When: Testing various server error statuses
    let serverErrors: [HTTPStatus] = [
      .internalServerError,  // 500
      .notImplemented,  // 501
      .badGateway,  // 502
      .serviceUnavailable,  // 503
      .gatewayTimeout,  // 504
    ]

    for status in serverErrors {
      let request = HTTPRequest(method: .get, path: "/api/data", baseURL: "https://api.com")
      let context = InterceptorContext(path: "/api/data", method: .get, metadata: [:])

      let response = HTTPResponse(
        request: request,
        status: status,
        headers: [:],
        body: nil
      )

      let result = try await interceptor.intercept(response: response, context: context)

      // Then: All server errors should trigger retry
      if case .retry(let delay) = result {
        XCTAssertNotNil(delay, "Delay should not be nil")
        XCTAssertGreaterThan(delay ?? 0, 0, "Should retry with delay for status \(status.rawValue)")
      } else {
        XCTFail("Expected .retry for status \(status.rawValue), got \(result)")
      }
    }
  }

  func testRetriesRequestTimeout() async throws {
    // Given: A retry interceptor
    let interceptor = RetryInterceptor(maxAttempts: 3, baseDelay: 0.1)

    // When: 408 Request Timeout
    let request = HTTPRequest(method: .get, path: "/api/slow", baseURL: "https://api.com")
    let context = InterceptorContext(path: "/api/slow", method: .get, metadata: [:])

    let response = HTTPResponse(
      request: request,
      status: .requestTimeout,
      headers: [:],
      body: nil
    )

    let result = try await interceptor.intercept(response: response, context: context)

    // Then: Should retry
    if case .retry(let delay) = result {
      XCTAssertNotNil(delay)
      XCTAssertGreaterThan(delay ?? 0, 0)
    } else {
      XCTFail("Expected .retry, got \(result)")
    }
  }

  func testRetriesRateLimit() async throws {
    // Given: A retry interceptor
    let interceptor = RetryInterceptor(maxAttempts: 3, baseDelay: 0.1)

    // When: 429 Too Many Requests
    let request = HTTPRequest(method: .get, path: "/api/limited", baseURL: "https://api.com")
    let context = InterceptorContext(path: "/api/limited", method: .get, metadata: [:])

    let response = HTTPResponse(
      request: request,
      status: .tooManyRequests,
      headers: [:],
      body: nil
    )

    let result = try await interceptor.intercept(response: response, context: context)

    // Then: Should retry
    if case .retry(let delay) = result {
      XCTAssertNotNil(delay)
      XCTAssertGreaterThan(delay ?? 0, 0)
    } else {
      XCTFail("Expected .retry, got \(result)")
    }
  }

  // MARK: - Non-Retryable Errors

  func testDoesNotRetryClientErrors() async throws {
    // Given: A retry interceptor
    let interceptor = RetryInterceptor(maxAttempts: 3, baseDelay: 0.1)

    // When: Testing various client error statuses
    let clientErrors: [HTTPStatus] = [
      .badRequest,  // 400
      .unauthorized,  // 401
      .forbidden,  // 403
      .notFound,  // 404
      .methodNotAllowed,  // 405
      .unprocessableEntity,  // 422
    ]

    for status in clientErrors {
      let request = HTTPRequest(method: .get, path: "/api/error", baseURL: "https://api.com")
      let context = InterceptorContext(path: "/api/error", method: .get, metadata: [:])

      let response = HTTPResponse(
        request: request,
        status: status,
        headers: [:],
        body: nil
      )

      let result = try await interceptor.intercept(response: response, context: context)

      // Then: Client errors should not retry
      if case .proceed = result {
        // Success
      } else {
        XCTFail("Expected .proceed for status \(status.rawValue), got \(result)")
      }
    }
  }

  func testDoesNotRetrySuccessResponses() async throws {
    // Given: A retry interceptor
    let interceptor = RetryInterceptor(maxAttempts: 3, baseDelay: 0.1)

    // When: Testing success statuses
    let successStatuses: [HTTPStatus] = [
      .ok,  // 200
      .created,  // 201
      .accepted,  // 202
      .noContent,  // 204
    ]

    for status in successStatuses {
      let request = HTTPRequest(method: .get, path: "/api/success", baseURL: "https://api.com")
      let context = InterceptorContext(path: "/api/success", method: .get, metadata: [:])

      let response = HTTPResponse(
        request: request,
        status: status,
        headers: [:],
        body: nil
      )

      let result = try await interceptor.intercept(response: response, context: context)

      // Then: Success should not retry
      if case .proceed = result {
        // Success
      } else {
        XCTFail("Expected .proceed for status \(status.rawValue), got \(result)")
      }
    }
  }

  // MARK: - Max Attempts

  func testRespectsMaxAttempts() async throws {
    // Given: Interceptor with max 2 attempts
    let interceptor = RetryInterceptor(maxAttempts: 2, baseDelay: 0.1)

    let request = HTTPRequest(
      method: .get,
      path: "/api/failing",
      baseURL: "https://api.com"
    )

    // When: First attempt (attemptCount = 0)
    let context1 = InterceptorContext(
      path: "/api/failing",
      method: .get,
      attemptCount: 0,
      metadata: [:]
    )

    let response = HTTPResponse(
      request: request,
      status: .internalServerError,
      headers: [:],
      body: nil
    )

    let result1 = try await interceptor.intercept(response: response, context: context1)

    // Then: Should retry (attempt 0 < max 2)
    if case .retry = result1 {
      // Success
    } else {
      XCTFail("Expected .retry for attempt 0, got \(result1)")
    }

    // When: Second attempt (attemptCount = 1)
    let context2 = InterceptorContext(
      path: "/api/failing",
      method: .get,
      attemptCount: 1,
      metadata: [:]
    )

    let result2 = try await interceptor.intercept(response: response, context: context2)

    // Then: Should retry (attempt 1 < max 2)
    if case .retry = result2 {
      // Success
    } else {
      XCTFail("Expected .retry for attempt 1, got \(result2)")
    }

    // When: Third attempt (attemptCount = 2, equals max)
    let context3 = InterceptorContext(
      path: "/api/failing",
      method: .get,
      attemptCount: 2,
      metadata: [:]
    )

    let result3 = try await interceptor.intercept(response: response, context: context3)

    // Then: Should not retry (attempt 2 >= max 2)
    if case .proceed = result3 {
      // Success
    } else {
      XCTFail("Expected .proceed at max attempts, got \(result3)")
    }
  }

  // MARK: - Exponential Backoff

  func testExponentialBackoffDelay() async throws {
    // Given: Interceptor with known base delay
    let interceptor = RetryInterceptor(maxAttempts: 5, baseDelay: 1.0, maxDelay: 100.0)

    let request = HTTPRequest(
      method: .get,
      path: "/api/retry",
      baseURL: "https://api.com"
    )

    let response = HTTPResponse(
      request: request,
      status: .internalServerError,
      headers: [:],
      body: nil
    )

    // When: Testing delays for different attempt counts
    for attemptCount in 0..<4 {
      let context = InterceptorContext(
        path: "/api/retry",
        method: .get,
        attemptCount: attemptCount,
        metadata: [:]
      )

      let result = try await interceptor.intercept(response: response, context: context)

      if case .retry(let delay) = result {
        XCTAssertNotNil(delay, "Delay should not be nil for attempt \(attemptCount)")
        guard let unwrappedDelay = delay else { continue }

        // Expected delay with jitter: baseDelay * (2^attemptCount) + jitter
        let expectedBase = 1.0 * pow(2.0, Double(attemptCount))

        // Verify delay is in expected range (base to base * 1.1 due to jitter)
        XCTAssertGreaterThanOrEqual(
          unwrappedDelay,
          expectedBase,
          "Delay for attempt \(attemptCount) should be >= \(expectedBase)"
        )
        XCTAssertLessThanOrEqual(
          unwrappedDelay,
          expectedBase * 1.1,
          "Delay for attempt \(attemptCount) should be <= \(expectedBase * 1.1)"
        )
      } else {
        XCTFail("Expected .retry for attempt \(attemptCount), got \(result)")
      }
    }
  }

  func testMaxDelayCapIsEnforced() async throws {
    // Given: Interceptor with low max delay cap
    let interceptor = RetryInterceptor(maxAttempts: 10, baseDelay: 1.0, maxDelay: 5.0)

    let request = HTTPRequest(
      method: .get,
      path: "/api/capped",
      baseURL: "https://api.com"
    )

    let response = HTTPResponse(
      request: request,
      status: .internalServerError,
      headers: [:],
      body: nil
    )

    // When: Testing high attempt count that would exceed max delay
    // Attempt 5: would be 1.0 * 2^5 = 32 seconds, but capped at 5
    let context = InterceptorContext(
      path: "/api/capped",
      method: .get,
      attemptCount: 5,
      metadata: [:]
    )

    let result = try await interceptor.intercept(response: response, context: context)

    // Then: Delay should be capped at maxDelay (5.0) + jitter
    if case .retry(let delay) = result {
      XCTAssertNotNil(delay)
      guard let unwrappedDelay = delay else {
        XCTFail("Delay should not be nil")
        return
      }
      XCTAssertLessThanOrEqual(unwrappedDelay, 5.5, "Delay should be capped at maxDelay + jitter")
      XCTAssertGreaterThanOrEqual(unwrappedDelay, 5.0, "Delay should be at least maxDelay")
    } else {
      XCTFail("Expected .retry, got \(result)")
    }
  }

  // MARK: - Jitter

  func testJitterPreventsThunderingHerd() async throws {
    // Given: Multiple interceptors with same configuration
    let interceptor = RetryInterceptor(maxAttempts: 3, baseDelay: 1.0)

    let request = HTTPRequest(
      method: .get,
      path: "/api/jitter",
      baseURL: "https://api.com"
    )

    let response = HTTPResponse(
      request: request,
      status: .internalServerError,
      headers: [:],
      body: nil
    )

    let context = InterceptorContext(
      path: "/api/jitter",
      method: .get,
      attemptCount: 1,
      metadata: [:]
    )

    // When: Getting delays from multiple retry decisions
    var delays: [TimeInterval] = []

    for _ in 0..<10 {
      let result = try await interceptor.intercept(response: response, context: context)

      if case .retry(let delay) = result, let unwrappedDelay = delay {
        delays.append(unwrappedDelay)
      }
    }

    // Then: Delays should vary due to jitter
    let uniqueDelays = Set(delays.map { Int($0 * 1000) })  // Round to milliseconds
    XCTAssertGreaterThan(
      uniqueDelays.count,
      1,
      "Jitter should produce varying delays"
    )
  }

  // MARK: - Integration with InterceptorChain

  func testWorksWithInterceptorChain() async throws {
    // Given: A chain with retry interceptor
    let retry = RetryInterceptor(maxAttempts: 3, baseDelay: 0.1)

    let chain = InterceptorChain(
      requestInterceptors: [],
      responseInterceptors: [retry]
    )

    // When: Executing chain with 500 response
    let request = HTTPRequest(
      method: .get,
      path: "/api/chain",
      baseURL: "https://example.com"
    )

    let context = InterceptorContext(
      path: "/api/chain",
      method: .get,
      metadata: [:]
    )

    let response = HTTPResponse(
      request: request,
      status: .internalServerError,
      headers: [:],
      body: nil
    )

    let result = try await chain.executeResponseInterceptors(
      response: response,
      context: context
    )

    // Then: Chain returns retry
    if case .retry(let delay) = result {
      XCTAssertNotNil(delay)
      XCTAssertGreaterThan(delay ?? 0, 0)
    } else {
      XCTFail("Expected .retry, got \(result)")
    }
  }

  // MARK: - Convenience Constructors

  func testAggressivePreset() async throws {
    let aggressive = RetryInterceptor.aggressive

    XCTAssertEqual(aggressive.maxAttempts, 5)
    XCTAssertEqual(aggressive.baseDelay, 0.5)
    XCTAssertEqual(aggressive.maxDelay, 30.0)
  }

  func testConservativePreset() async throws {
    let conservative = RetryInterceptor.conservative

    XCTAssertEqual(conservative.maxAttempts, 2)
    XCTAssertEqual(conservative.baseDelay, 2.0)
    XCTAssertEqual(conservative.maxDelay, 60.0)
  }

  func testStandardPreset() async throws {
    let standard = RetryInterceptor.standard

    XCTAssertEqual(standard.maxAttempts, 3)
    XCTAssertEqual(standard.baseDelay, 1.0)
    XCTAssertEqual(standard.maxDelay, 60.0)
  }
}
