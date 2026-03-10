import Foundation
import XCTest

@testable import NetworkingInterceptorsCompat
import NetworkingRuntime
import NetworkingDSL
import NetworkingTesting

// swiftlint:disable file_length

/// Tests for RateLimitInterceptor
final class RateLimitInterceptorTests: XCTestCase {
  // MARK: - Basic Rate Limiting

  func testAllowsRequestsUnderLimit() async throws {
    // Given: Rate limiter allowing 3 requests per second
    let interceptor = RateLimitInterceptor(
      requestsPerWindow: 3,
      windowDuration: 1.0,
      strategy: .delay
    )

    // When: Making 3 requests (under limit)
    for i in 1...3 {
      var request = HTTPRequest(method: .get, path: "/api/data", baseURL: "https://api.com")
      let context = InterceptorContext(path: "/api/data", method: .get, metadata: [:])

      let result = try await interceptor.intercept(request: &request, context: context)

      // Then: All requests should proceed
      if case .proceed = result {
        // Success
      } else {
        XCTFail("Request \(i) should proceed, got \(result)")
      }
    }
  }

  func testDelaysRequestsAtLimit() async throws {
    // Given: Rate limiter with delay strategy
    let interceptor = RateLimitInterceptor(
      requestsPerWindow: 2,
      windowDuration: 1.0,
      strategy: .delay
    )

    // When: Making 2 requests (fills limit)
    var request1 = HTTPRequest(method: .get, path: "/api/data", baseURL: "https://api.com")
    let context1 = InterceptorContext(path: "/api/data", method: .get, metadata: [:])
    _ = try await interceptor.intercept(request: &request1, context: context1)

    var request2 = HTTPRequest(method: .get, path: "/api/data", baseURL: "https://api.com")
    let context2 = InterceptorContext(path: "/api/data", method: .get, metadata: [:])
    _ = try await interceptor.intercept(request: &request2, context: context2)

    // When: Making third request (exceeds limit)
    var request3 = HTTPRequest(method: .get, path: "/api/data", baseURL: "https://api.com")
    let context3 = InterceptorContext(path: "/api/data", method: .get, metadata: [:])

    let result = try await interceptor.intercept(request: &request3, context: context3)

    // Then: Third request should be delayed
    if case .retry(let delay) = result {
      XCTAssertNotNil(delay, "Delay should be provided")
      XCTAssertGreaterThan(delay?.rawValue ?? 0, 0, "Delay should be greater than 0")
    } else {
      XCTFail("Expected .retry with delay, got \(result)")
    }
  }

  func testRejectsRequestsAtLimit() async throws {
    // Given: Rate limiter with reject strategy
    let interceptor = RateLimitInterceptor(
      requestsPerWindow: 2,
      windowDuration: 1.0,
      strategy: .reject
    )

    // When: Making 2 requests (fills limit)
    var request1 = HTTPRequest(method: .get, path: "/api/data", baseURL: "https://api.com")
    let context1 = InterceptorContext(path: "/api/data", method: .get, metadata: [:])
    _ = try await interceptor.intercept(request: &request1, context: context1)

    var request2 = HTTPRequest(method: .get, path: "/api/data", baseURL: "https://api.com")
    let context2 = InterceptorContext(path: "/api/data", method: .get, metadata: [:])
    _ = try await interceptor.intercept(request: &request2, context: context2)

    // When: Making third request (exceeds limit)
    var request3 = HTTPRequest(method: .get, path: "/api/data", baseURL: "https://api.com")
    let context3 = InterceptorContext(path: "/api/data", method: .get, metadata: [:])

    // Then: Third request should throw error
    do {
      _ = try await interceptor.intercept(request: &request3, context: context3)
      XCTFail("Expected rateLimitExceeded error")
    } catch let error as InterceptorError {
      if case .rateLimitExceeded(let path, let limit, let window) = error {
        XCTAssertEqual(path, RequestPathPattern("/api/data"))
        XCTAssertEqual(limit, RequestCount(2))
        XCTAssertEqual(window, RateLimitWindowDuration(1.0))
      } else {
        XCTFail("Expected rateLimitExceeded error, got \(error)")
      }
    } catch {
      XCTFail("Expected InterceptorError, got \(error)")
    }
  }

  // MARK: - Per-Endpoint Tracking

  func testTracksEndpointsSeparately() async throws {
    // Given: Rate limiter allowing 2 requests per second
    let interceptor = RateLimitInterceptor(
      requestsPerWindow: 2,
      windowDuration: 1.0,
      strategy: .delay
    )

    // When: Making 2 requests to /api/users (fills that endpoint's limit)
    var usersRequest1 = HTTPRequest(method: .get, path: "/api/users", baseURL: "https://api.com")
    let usersContext1 = InterceptorContext(path: "/api/users", method: .get, metadata: [:])
    _ = try await interceptor.intercept(request: &usersRequest1, context: usersContext1)

    var usersRequest2 = HTTPRequest(method: .get, path: "/api/users", baseURL: "https://api.com")
    let usersContext2 = InterceptorContext(path: "/api/users", method: .get, metadata: [:])
    _ = try await interceptor.intercept(request: &usersRequest2, context: usersContext2)

    // When: Making request to different endpoint /api/posts
    var postsRequest = HTTPRequest(method: .get, path: "/api/posts", baseURL: "https://api.com")
    let postsContext = InterceptorContext(path: "/api/posts", method: .get, metadata: [:])

    let result = try await interceptor.intercept(request: &postsRequest, context: postsContext)

    // Then: /api/posts request should proceed (different endpoint)
    if case .proceed = result {
      // Success - endpoints tracked separately
    } else {
      XCTFail("Different endpoint should have separate limit, got \(result)")
    }
  }

  // MARK: - Sliding Window

  func testSlidingWindowExpiration() async throws {
    // Given: Rate limiter with 2 requests per 0.2 second window
    let interceptor = RateLimitInterceptor(
      requestsPerWindow: 2,
      windowDuration: 0.2,
      strategy: .delay
    )

    // When: Making 2 requests (fills limit)
    var request1 = HTTPRequest(method: .get, path: "/api/temp", baseURL: "https://api.com")
    let context1 = InterceptorContext(path: "/api/temp", method: .get, metadata: [:])
    _ = try await interceptor.intercept(request: &request1, context: context1)

    var request2 = HTTPRequest(method: .get, path: "/api/temp", baseURL: "https://api.com")
    let context2 = InterceptorContext(path: "/api/temp", method: .get, metadata: [:])
    _ = try await interceptor.intercept(request: &request2, context: context2)

    // Wait for window to expire
    try await Task.sleep(nanoseconds: 250_000_000)  // 250ms > 200ms window

    // When: Making request after window expiration
    var request3 = HTTPRequest(method: .get, path: "/api/temp", baseURL: "https://api.com")
    let context3 = InterceptorContext(path: "/api/temp", method: .get, metadata: [:])

    let result = try await interceptor.intercept(request: &request3, context: context3)

    // Then: Request should proceed (old requests expired)
    if case .proceed = result {
      // Success - window slid and old requests expired
    } else {
      XCTFail("Request should proceed after window expiration, got \(result)")
    }
  }

  // MARK: - Reset Functionality

  func testResetClearsAllHistory() async throws {
    // Given: Rate limiter with requests at limit
    let interceptor = RateLimitInterceptor(
      requestsPerWindow: 1,
      windowDuration: 10.0,  // Long window
      strategy: .delay
    )

    // When: Making request (fills limit)
    var request1 = HTTPRequest(method: .get, path: "/api/data", baseURL: "https://api.com")
    let context1 = InterceptorContext(path: "/api/data", method: .get, metadata: [:])
    _ = try await interceptor.intercept(request: &request1, context: context1)

    // When: Resetting all history
    await interceptor.reset()

    // When: Making another request
    var request2 = HTTPRequest(method: .get, path: "/api/data", baseURL: "https://api.com")
    let context2 = InterceptorContext(path: "/api/data", method: .get, metadata: [:])

    let result = try await interceptor.intercept(request: &request2, context: context2)

    // Then: Request should proceed (history cleared)
    if case .proceed = result {
      // Success
    } else {
      XCTFail("Request should proceed after reset, got \(result)")
    }
  }

  func testResetClearsSpecificPath() async throws {
    // Given: Rate limiter with requests at limit for two endpoints
    let interceptor = RateLimitInterceptor(
      requestsPerWindow: 1,
      windowDuration: 10.0,
      strategy: .delay
    )

    // Fill limit for /api/users
    var usersRequest = HTTPRequest(method: .get, path: "/api/users", baseURL: "https://api.com")
    let usersContext = InterceptorContext(path: "/api/users", method: .get, metadata: [:])
    _ = try await interceptor.intercept(request: &usersRequest, context: usersContext)

    // Fill limit for /api/posts
    var postsRequest1 = HTTPRequest(method: .get, path: "/api/posts", baseURL: "https://api.com")
    let postsContext1 = InterceptorContext(path: "/api/posts", method: .get, metadata: [:])
    _ = try await interceptor.intercept(request: &postsRequest1, context: postsContext1)

    // When: Resetting only /api/users
    await interceptor.reset(path: "/api/users")

    // Then: /api/users should allow new request
    var usersRequest2 = HTTPRequest(method: .get, path: "/api/users", baseURL: "https://api.com")
    let usersContext2 = InterceptorContext(path: "/api/users", method: .get, metadata: [:])
    let usersResult = try await interceptor.intercept(
      request: &usersRequest2,
      context: usersContext2
    )

    if case .proceed = usersResult {
      // Success
    } else {
      XCTFail("/api/users should proceed after reset, got \(usersResult)")
    }

    // Then: /api/posts should still be at limit
    var postsRequest2 = HTTPRequest(method: .get, path: "/api/posts", baseURL: "https://api.com")
    let postsContext2 = InterceptorContext(path: "/api/posts", method: .get, metadata: [:])
    let postsResult = try await interceptor.intercept(
      request: &postsRequest2,
      context: postsContext2
    )

    if case .retry = postsResult {
      // Success - still at limit
    } else {
      XCTFail("/api/posts should still be limited, got \(postsResult)")
    }
  }

  // MARK: - Convenience Constructors

  func testStrictPreset() async throws {
    let strict = RateLimitInterceptor.strict

    XCTAssertEqual(strict.requestsPerWindow, 60)
    XCTAssertEqual(strict.windowDuration, 60.0)

    // Verify reject strategy by attempting to exceed limit
    // (We can't directly access the strategy enum, so test behavior)
    for _ in 1...60 {
      var request = HTTPRequest(method: .get, path: "/test", baseURL: "https://api.com")
      let context = InterceptorContext(path: "/test", method: .get, metadata: [:])
      _ = try? await strict.intercept(request: &request, context: context)
    }

    var exceededRequest = HTTPRequest(method: .get, path: "/test", baseURL: "https://api.com")
    let exceededContext = InterceptorContext(path: "/test", method: .get, metadata: [:])

    do {
      _ = try await strict.intercept(request: &exceededRequest, context: exceededContext)
      XCTFail("Strict preset should reject at limit")
    } catch is InterceptorError {
      // Success - reject strategy confirmed
    }
  }

  func testLenientPreset() async throws {
    let lenient = RateLimitInterceptor.lenient

    XCTAssertEqual(lenient.requestsPerWindow, 100)
    XCTAssertEqual(lenient.windowDuration, 60.0)

    // Verify delay strategy by checking it doesn't throw at limit
    for _ in 1...100 {
      var request = HTTPRequest(method: .get, path: "/test", baseURL: "https://api.com")
      let context = InterceptorContext(path: "/test", method: .get, metadata: [:])
      _ = try? await lenient.intercept(request: &request, context: context)
    }

    var exceededRequest = HTTPRequest(method: .get, path: "/test", baseURL: "https://api.com")
    let exceededContext = InterceptorContext(path: "/test", method: .get, metadata: [:])

    let result = try await lenient.intercept(request: &exceededRequest, context: exceededContext)

    // Should delay, not throw
    if case .retry = result {
      // Success - delay strategy confirmed
    } else {
      XCTFail("Lenient preset should use delay strategy")
    }
  }

  func testPerSecondPreset() async throws {
    let perSecond = RateLimitInterceptor.perSecond

    XCTAssertEqual(perSecond.requestsPerWindow, 10)
    XCTAssertEqual(perSecond.windowDuration, 1.0)
  }
}
