import Foundation
import XCTest

@testable import NetworkingInterceptorsCompat
import NetworkingRuntime
import NetworkingDSL
import NetworkingTesting

// swiftlint:disable file_length

/// Thread-safe token storage for testing using NSLock
final class TokenStorage: @unchecked Sendable {
  private var accessToken: String?
  private var refreshToken: String?
  private let lock = NSLock()

  func update(accessToken: String, refreshToken: String) {
    lock.lock()
    defer { lock.unlock() }
    self.accessToken = accessToken
    self.refreshToken = refreshToken
  }

  func getTokens() -> (accessToken: String?, refreshToken: String?) {
    lock.lock()
    defer { lock.unlock() }
    return (accessToken, refreshToken)
  }
}

/// Tests for TokenRefreshInterceptor
final class TokenRefreshInterceptorTests: XCTestCase {  // swiftlint:disable:this type_body_length
  private func makeInterceptor(
    refreshHandler: @escaping TokenRefreshInterceptor.RefreshHandler,
    tokenUpdateHandler: @escaping TokenRefreshInterceptor.TokenUpdateHandler = { _, _ in }
  ) -> TokenRefreshInterceptor {
    TokenRefreshInterceptor(
      refreshHandler: refreshHandler,
      tokenUpdateHandler: tokenUpdateHandler
    )
  }

  // MARK: - Basic Token Refresh

  // swiftlint:disable:next function_body_length
  func testRefreshesTokenOn401Response() async throws {
    // Given: An interceptor with a refresh handler
    let storage = TokenStorage()
    actor RefreshCounter {
      private(set) var count = 0
      func increment() {
        count += 1
      }
    }
    let counter = RefreshCounter()

    let interceptor = makeInterceptor(
      refreshHandler: { refreshToken in
        await counter.increment()
        XCTAssertEqual(refreshToken.rawValue, "old-refresh-token")
        return ("new-access-token", "new-refresh-token")
      },
      tokenUpdateHandler: { accessToken, refreshToken in
        storage.update(
          accessToken: accessToken.rawValue,
          refreshToken: refreshToken.rawValue
        )
      }
    )

    // When: Intercepting a 401 response
    let request = HTTPRequest(method: .get, path: "/protected", baseURL: "https://api.com")
    let context = InterceptorContext(
      path: "/protected",
      method: .get,
      metadata: ["refreshToken": .string("old-refresh-token")]
    )

    let response = HTTPResponse(
      request: request,
      status: .unauthorized,
      headers: [:],
      body: nil
    )

    let result = try await interceptor.intercept(response: response, context: context)

    // Then: Tokens are refreshed and request is retried
    if case .retry(let delay) = result {
      XCTAssertEqual(delay, RetryDelay(0), "Should retry immediately")
    } else {
      XCTFail("Expected .retry, got \(result)")
    }

    let refreshCount = await counter.count
    XCTAssertEqual(refreshCount, 1)

    // Verify tokens were updated
    let tokens = storage.getTokens()
    XCTAssertEqual(tokens.accessToken, "new-access-token")
    XCTAssertEqual(tokens.refreshToken, "new-refresh-token")
  }

  func testDoesNotRefreshOnSuccessResponse() async throws {
    // Given: An interceptor
    actor RefreshCounter {
      private(set) var count = 0
      func increment() {
        count += 1
      }
    }
    let counter = RefreshCounter()

    let interceptor = makeInterceptor(
      refreshHandler: { _ in
        await counter.increment()
        return ("new-token", "new-refresh")
      },
      tokenUpdateHandler: { _, _ in }
    )

    // When: Intercepting a 200 response
    let request = HTTPRequest(method: .get, path: "/api/data", baseURL: "https://api.com")
    let context = InterceptorContext(path: "/api/data", method: .get, metadata: [:])

    let response = HTTPResponse(
      request: request,
      status: .ok,
      headers: [:],
      body: nil
    )

    let result = try await interceptor.intercept(response: response, context: context)

    // Then: No refresh occurs
    if case .proceed = result {
      // Success
    } else {
      XCTFail("Expected .proceed, got \(result)")
    }

    let refreshCount = await counter.count
    XCTAssertEqual(refreshCount, 0)
  }

  // MARK: - Error Handling

  func testHandlesMissingRefreshToken() async throws {
    // Given: An interceptor
    actor RefreshCounter {
      private(set) var count = 0
      func increment() {
        count += 1
      }
    }
    let counter = RefreshCounter()

    let interceptor = makeInterceptor(
      refreshHandler: { _ in
        await counter.increment()
        return ("new-token", "new-refresh")
      },
      tokenUpdateHandler: { _, _ in }
    )

    // When: 401 response without refresh token in context
    let request = HTTPRequest(method: .get, path: "/protected", baseURL: "https://api.com")
    let context = InterceptorContext(path: "/protected", method: .get, metadata: [:])

    let response = HTTPResponse(
      request: request,
      status: .unauthorized,
      headers: [:],
      body: nil
    )

    let result = try await interceptor.intercept(response: response, context: context)

    // Then: Proceeds without refresh
    if case .proceed = result {
      // Success
    } else {
      XCTFail("Expected .proceed, got \(result)")
    }

    let refreshCount = await counter.count
    XCTAssertEqual(refreshCount, 0)
  }

  func testHandlesRefreshFailure() async throws {
    // Given: An interceptor with failing refresh handler
    struct RefreshError: Error, Equatable {}

    let interceptor = makeInterceptor(
      refreshHandler: { _ in
        throw RefreshError()
      },
      tokenUpdateHandler: { _, _ in }
    )

    // When: 401 response triggers refresh
    let request = HTTPRequest(method: .get, path: "/protected", baseURL: "https://api.com")
    let context = InterceptorContext(
      path: "/protected",
      method: .get,
      metadata: ["refreshToken": .string("old-refresh")]
    )

    let response = HTTPResponse(
      request: request,
      status: .unauthorized,
      headers: [:],
      body: nil
    )

    let result = try await interceptor.intercept(response: response, context: context)

    // Then: Proceeds without retry (refresh failed)
    if case .proceed = result {
      // Success - refresh failure is handled gracefully
    } else {
      XCTFail("Expected .proceed on refresh failure, got \(result)")
    }
  }

  // MARK: - Concurrent Refresh Prevention

  func testPreventsConcurrentRefreshes() async throws {
    // Given: An interceptor with slow refresh handler
    actor RefreshCounter {
      private(set) var count = 0

      func increment() {
        count += 1
      }
    }

    let counter = RefreshCounter()

    let interceptor = makeInterceptor(
      refreshHandler: { _ in
        await counter.increment()
        // Simulate slow network call
        try await Task.sleep(nanoseconds: 50_000_000)  // 50ms
        return ("new-token", "new-refresh")
      },
      tokenUpdateHandler: { _, _ in }
    )

    let request = HTTPRequest(method: .get, path: "/protected", baseURL: "https://api.com")
    let context = InterceptorContext(
      path: "/protected",
      method: .get,
      metadata: ["refreshToken": .string("old-refresh")]
    )

    let response = HTTPResponse(
      request: request,
      status: .unauthorized,
      headers: [:],
      body: nil
    )

    // When: Multiple concurrent 401 responses
    async let result1 = interceptor.intercept(response: response, context: context)
    async let result2 = interceptor.intercept(response: response, context: context)
    async let result3 = interceptor.intercept(response: response, context: context)

    let results = try await [result1, result2, result3]

    // Then: All should return retry
    for result in results {
      if case .retry = result {
        // Success
      } else {
        XCTFail("Expected .retry, got \(result)")
      }
    }

    // But refresh handler should only be called once
    let finalCount = await counter.count
    XCTAssertEqual(finalCount, 1, "Refresh should only occur once for concurrent requests")
  }

  // MARK: - Token Update Handler

  func testCallsTokenUpdateHandler() async throws {
    // Given: An interceptor with token update handler
    let storage = TokenStorage()

    let interceptor = makeInterceptor(
      refreshHandler: { _ in
        ("updated-access", "updated-refresh")
      },
      tokenUpdateHandler: { accessToken, refreshToken in
        storage.update(
          accessToken: accessToken.rawValue,
          refreshToken: refreshToken.rawValue
        )
      }
    )

    // When: 401 triggers refresh
    let request = HTTPRequest(method: .get, path: "/protected", baseURL: "https://api.com")
    let context = InterceptorContext(
      path: "/protected",
      method: .get,
      metadata: ["refreshToken": .string("old-refresh")]
    )

    let response = HTTPResponse(
      request: request,
      status: .unauthorized,
      headers: [:],
      body: nil
    )

    _ = try await interceptor.intercept(response: response, context: context)

    // Then: Token update handler was called
    let tokens = storage.getTokens()
    XCTAssertEqual(tokens.accessToken, "updated-access")
    XCTAssertEqual(tokens.refreshToken, "updated-refresh")
  }

  // MARK: - Integration with InterceptorChain

  func testWorksWithInterceptorChain() async throws {
    // Given: A chain with token refresh interceptor
    let storage = TokenStorage()

    let refreshInterceptor = makeInterceptor(
      refreshHandler: { _ in
        ("chain-new-token", "chain-new-refresh")
      },
      tokenUpdateHandler: { accessToken, refreshToken in
        storage.update(
          accessToken: accessToken.rawValue,
          refreshToken: refreshToken.rawValue
        )
      }
    )

    let chain = InterceptorChain(
      requestInterceptors: [],
      responseInterceptors: [refreshInterceptor]
    )

    // When: Executing chain with 401 response
    let request = HTTPRequest(method: .get, path: "/api/secure", baseURL: "https://example.com")
    let context = InterceptorContext(
      path: "/api/secure",
      method: .get,
      metadata: ["refreshToken": .string("chain-old-refresh")]
    )

    let response = HTTPResponse(
      request: request,
      status: .unauthorized,
      headers: [:],
      body: nil
    )

    let result = try await chain.executeResponseInterceptors(
      response: response,
      context: context
    )

    // Then: Chain returns retry
    if case .retry = result {
      // Success
    } else {
      XCTFail("Expected .retry, got \(result)")
    }

    // And tokens are updated
    let tokens = storage.getTokens()
    XCTAssertEqual(tokens.accessToken, "chain-new-token")
    XCTAssertEqual(tokens.refreshToken, "chain-new-refresh")
  }

  // MARK: - Edge Cases

  func testHandles401WithoutRetry() async throws {
    // Given: Interceptor that refreshes but context has no refresh token
    let interceptor = makeInterceptor(
      refreshHandler: { _ in ("new", "new") },
      tokenUpdateHandler: { _, _ in }
    )

    // When: 401 with no refresh token
    let request = HTTPRequest(method: .get, path: "/protected", baseURL: "https://api.com")
    let context = InterceptorContext(path: "/protected", method: .get, metadata: [:])

    let response = HTTPResponse(
      request: request,
      status: .unauthorized,
      headers: [:],
      body: nil
    )

    let result = try await interceptor.intercept(response: response, context: context)

    // Then: Proceeds without refresh
    if case .proceed = result {
      // Success
    } else {
      XCTFail("Expected .proceed, got \(result)")
    }
  }

  func testHandlesOtherErrorStatuses() async throws {
    // Given: An interceptor
    let interceptor = makeInterceptor(
      refreshHandler: { _ in ("new", "new") },
      tokenUpdateHandler: { _, _ in }
    )

    // When: Testing various non-401 error statuses
    let statuses: [HTTPStatus] = [.badRequest, .forbidden, .notFound, .internalServerError]

    for status in statuses {
      let request = HTTPRequest(method: .get, path: "/test", baseURL: "https://api.com")
      let context = InterceptorContext(
        path: "/test",
        method: .get,
        metadata: ["refreshToken": .string("token")]
      )

      let response = HTTPResponse(
        request: request,
        status: status,
        headers: [:],
        body: nil
      )

      let result = try await interceptor.intercept(response: response, context: context)

      // Then: All proceed without refresh
      if case .proceed = result {
        // Success
      } else {
        XCTFail("Expected .proceed for status \(status.rawValue), got \(result)")
      }
    }
  }
}
