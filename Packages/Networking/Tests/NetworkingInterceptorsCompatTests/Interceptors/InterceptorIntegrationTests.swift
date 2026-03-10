import Foundation
import XCTest

@testable import NetworkingInterceptorsCompat
import NetworkingRuntime
import NetworkingDSL
import NetworkingTesting

/// End-to-end integration tests for multiple interceptors working together.
///
/// These tests validate real-world scenarios where multiple interceptors
/// collaborate to provide authentication, caching, retry logic, rate limiting,
/// and logging in a single request/response cycle.
final class InterceptorIntegrationTests: XCTestCase {
    // MARK: - Test Helpers

    func makeRequest(path: String = "/api/data") -> HTTPRequest {
        HTTPRequest(method: .get, path: path, baseURL: "https://api.example.com")
    }

    func makeResponse(
        status: HTTPStatus = .ok,
        body: String? = nil
    ) -> HTTPResponse {
        HTTPResponse(
            request: makeRequest(),
            status: status,
            headers: [:],
            body: body?.data(using: .utf8)
        )
    }

    func makeContext(
        path: String = "/api/data",
        method: HTTPMethod = .get,
        attemptCount: Int = 0
    ) -> InterceptorContext {
        InterceptorContext(
            path: path,
            method: method,
            attemptCount: attemptCount,
            metadata: [:]
        )
    }

    // MARK: - Authentication + Retry

    func testAuthenticationWithRetryOnServerError() async throws {
        // Given: Auth interceptor + Retry interceptor
        let auth = AuthenticationInterceptor.bearer("initial-token")
        let retry = RetryInterceptor(maxAttempts: 1, baseDelay: 0.1)

        let requestChain = InterceptorChain(requestInterceptors: [auth])
        let responseChain = InterceptorChain(responseInterceptors: [retry])

        // When: Making authenticated request
        var request = makeRequest()
        let requestContext = makeContext()

        _ = try await requestChain.executeRequestInterceptors(
            request: &request,
            context: requestContext
        )

        // Verify auth header was added
        XCTAssertEqual(request.headers["Authorization"], "Bearer initial-token")

        // When: Response is 503 (server error that should retry)
        let response503 = makeResponse(status: .serviceUnavailable)
        let responseContext = makeContext()

        let retryResult = try await responseChain.executeResponseInterceptors(
            response: response503,
            context: responseContext
        )

        // Then: Retry is triggered
        if case .retry = retryResult {
            // Success - retry will happen with auth header still present
        } else {
            XCTFail("Expected retry on 503 server error")
        }
    }

    // MARK: - Caching + Rate Limiting

    func testCachingWithRateLimiting() async throws {
        // Given: Cache interceptor + Rate limit interceptor
        let cache = CachingInterceptor(ttl: 300, maxEntries: 10)
        let rateLimit = RateLimitInterceptor(
            requestsPerWindow: 2,
            windowDuration: 1.0,
            strategy: .delay
        )

        // When: Making first request (should pass rate limit and cache response)
        var request1 = makeRequest(path: "/api/users")
        let requestContext1 = makeContext(path: "/api/users")

        let rateLimitResult1 = try await rateLimit.intercept(
            request: &request1,
            context: requestContext1
        )

        // Then: First request proceeds
        if case .proceed = rateLimitResult1 {
            // Success
        } else {
            XCTFail("First request should proceed")
        }

        // Cache the response
        let response1 = makeResponse(body: "user data")
        let responseContext1 = makeContext(path: "/api/users")

        _ = try await cache.intercept(response: response1, context: responseContext1)

        // Verify cached
        let cached = await cache.getCachedResponse(for: .get, path: "/api/users")
        XCTAssertNotNil(cached)

        // When: Making second request (should pass rate limit)
        var request2 = makeRequest(path: "/api/users")
        let requestContext2 = makeContext(path: "/api/users")

        let rateLimitResult2 = try await rateLimit.intercept(
            request: &request2,
            context: requestContext2
        )

        // Then: Second request proceeds (2 of 2)
        if case .proceed = rateLimitResult2 {
            // Success
        } else {
            XCTFail("Second request should proceed")
        }

        // When: Making third request (exceeds rate limit)
        var request3 = makeRequest(path: "/api/users")
        let requestContext3 = makeContext(path: "/api/users")

        let rateLimitResult3 = try await rateLimit.intercept(
            request: &request3,
            context: requestContext3
        )

        // Then: Third request is delayed, but cache can serve it
        if case .retry = rateLimitResult3 {
            // Rate limited, but cache has data
            let cachedData = await cache.getCachedResponse(for: .get, path: "/api/users")
            XCTAssertNotNil(cachedData, "Cache should serve rate-limited request")
        } else {
            XCTFail("Third request should be rate limited")
        }
    }

    // MARK: - Token Refresh + Retry

    func testTokenRefreshWithRetry() async throws {
        // Given: Token refresh interceptor + Retry interceptor
        let storage = IntegrationTokenStorage()
        storage.update(accessToken: "old-token", refreshToken: "valid-refresh")

        let tokenRefresh = TokenRefreshInterceptor(
            refreshHandler: { _ in
                ("new-access-token", "new-refresh-token")
            },
            tokenUpdateHandler: { accessToken, refreshToken in
                storage.update(accessToken: accessToken, refreshToken: refreshToken)
            }
        )

        _ = RetryInterceptor(maxAttempts: 1, baseDelay: 0.1)

        // When: Getting 401 response
        let response401 = makeResponse(status: .unauthorized)
        let context = makeContext()
        let contextWithRefreshToken = InterceptorContext(
            path: context.path,
            method: context.method,
            attemptCount: context.attemptCount,
            metadata: ["refreshToken": .string("valid-refresh")]
        )

        // Token refresh should trigger on 401
        let tokenRefreshResult = try await tokenRefresh.intercept(
            response: response401,
            context: contextWithRefreshToken
        )

        // Then: Token refresh triggers retry
        if case .retry = tokenRefreshResult {
            // Verify tokens were updated
            let tokens = storage.getTokens()
            XCTAssertEqual(tokens.accessToken, "new-access-token")
            XCTAssertEqual(tokens.refreshToken, "new-refresh-token")
        } else {
            XCTFail("Expected retry after token refresh")
        }
    }

    // MARK: - Full Stack Integration

    func testFullStackIntegration() async throws {
        // Given: Complete interceptor stack
        let auth = AuthenticationInterceptor.bearer("valid-token")
        let rateLimit = RateLimitInterceptor(requestsPerWindow: 10, windowDuration: 1.0)
        let cache = CachingInterceptor(ttl: 300)
        let retry = RetryInterceptor(maxAttempts: 2, baseDelay: 0.1)

        let requestChain = InterceptorChain(
            requestInterceptors: [auth, rateLimit]
        )

        let responseChain = InterceptorChain(
            responseInterceptors: [cache, retry]
        )

        // When: Making successful request
        var request = makeRequest()
        let requestContext = makeContext()

        let requestResult = try await requestChain.executeRequestInterceptors(
            request: &request,
            context: requestContext
        )

        // Then: Request interceptors succeed
        if case .proceed = requestResult {
            // Verify auth header
            XCTAssertEqual(request.headers["Authorization"], "Bearer valid-token")
        } else {
            XCTFail("Request should proceed")
        }

        // When: Processing successful response
        let response = makeResponse(body: "success data")
        let responseContext = makeContext()

        let responseResult = try await responseChain.executeResponseInterceptors(
            response: response,
            context: responseContext
        )

        // Then: Response is cached and proceeds
        if case .proceed = responseResult {
            // Verify caching worked
            let cached = await cache.getCachedResponse(for: .get, path: "/api/data")
            XCTAssertNotNil(cached)
            XCTAssertEqual(cached?.body, "success data".data(using: .utf8))
        } else {
            XCTFail("Response should proceed")
        }
    }

    // MARK: - Logging Integration

    func testLoggingWithOtherInterceptors() async throws {
        // Given: Logging + Auth + Retry
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

            func count() -> Int {
                lock.lock()
                defer { lock.unlock() }
                return messages.count
            }
        }

        let collector = LogCollector()
        let logging = LoggingInterceptor(level: .basic) { message in
            collector.append(message)
        }

        let auth = AuthenticationInterceptor.bearer("test-token")
        let retry = RetryInterceptor(maxAttempts: 1, baseDelay: 0.1)

        let requestChain = InterceptorChain(
            requestInterceptors: [logging, auth]
        )

        let responseChain = InterceptorChain(
            responseInterceptors: [logging, retry]
        )

        // When: Making request
        var request = makeRequest()
        let requestContext = makeContext()

        _ = try await requestChain.executeRequestInterceptors(
            request: &request,
            context: requestContext
        )

        // Then: Request was logged
        XCTAssertGreaterThan(collector.count(), 0, "Request should be logged")

        // When: Processing response
        let response = makeResponse()
        let responseContext = makeContext()

        _ = try await responseChain.executeResponseInterceptors(
            response: response,
            context: responseContext
        )

        // Then: Response was logged
        XCTAssertGreaterThan(collector.count(), 1, "Response should also be logged")
    }

    // MARK: - Error Propagation

    func testErrorPropagationThroughChain() async throws {
        // Given: Rate limiter with reject strategy
        let rateLimitStrict = RateLimitInterceptor(
            requestsPerWindow: 1,
            windowDuration: 1.0,
            strategy: .reject
        )

        // Fill the rate limit
        var request1 = makeRequest()
        let context1 = makeContext()
        _ = try await rateLimitStrict.intercept(request: &request1, context: context1)

        // When: Exceeding rate limit with reject strategy
        var request2 = makeRequest()
        let context2 = makeContext()

        do {
            _ = try await rateLimitStrict.intercept(request: &request2, context: context2)
            XCTFail("Should throw rate limit error")
        } catch let error as InterceptorError {
            // Then: Error is properly typed
            if case let .rateLimitExceeded(path, limit, window) = error {
                XCTAssertEqual(path, "/api/data")
                XCTAssertEqual(limit, 1)
                XCTAssertEqual(window, 1.0)
            } else {
                XCTFail("Expected rateLimitExceeded error")
            }
        }
    }

    // MARK: - Interceptor Ordering

    func testInterceptorOrderMatters() async throws {
        // Given: Auth before rate limiting (correct order)
        let auth = AuthenticationInterceptor.bearer("token")
        let rateLimit = RateLimitInterceptor(requestsPerWindow: 1, windowDuration: 1.0)

        let correctOrderChain = InterceptorChain(
            requestInterceptors: [auth, rateLimit] // Auth first
        )

        // When: Making request with correct order
        var request = makeRequest()
        let context = makeContext()

        _ = try await correctOrderChain.executeRequestInterceptors(
            request: &request,
            context: context
        )

        // Then: Auth header is added before rate limiting
        XCTAssertEqual(request.headers["Authorization"], "Bearer token")
    }

    // MARK: - Cache + Retry Interaction

    func testCacheInvalidationOnRetry() async throws {
        // Given: Cache + Retry
        let cache = CachingInterceptor(ttl: 300)
        let retry = RetryInterceptor(maxAttempts: 2, baseDelay: 0.1)

        // When: Caching successful response
        let successResponse = makeResponse(body: "cached data")
        let context = makeContext()

        _ = try await cache.intercept(response: successResponse, context: context)

        // Verify cached
        let cached1 = await cache.getCachedResponse(for: .get, path: "/api/data")
        XCTAssertNotNil(cached1)

        // When: Getting error response that triggers retry
        let errorResponse = makeResponse(status: .internalServerError)
        let retryContext = makeContext()

        let retryResult = try await retry.intercept(
            response: errorResponse,
            context: retryContext
        )

        // Then: Retry is triggered
        if case .retry = retryResult {
            // Cache still has old data (not invalidated by retry)
            let cached2 = await cache.getCachedResponse(for: .get, path: "/api/data")
            XCTAssertNotNil(cached2, "Cache should persist across retries")
        } else {
            XCTFail("Expected retry on 500 error")
        }
    }

    // MARK: - Performance

    func testInterceptorChainPerformance() async throws {
        // Given: Full interceptor stack
        let auth = AuthenticationInterceptor.bearer("perf-token")
        let logging = LoggingInterceptor(level: .none) // Disabled for perf
        let cache = CachingInterceptor(ttl: 300)
        let retry = RetryInterceptor(maxAttempts: 3)
        let rateLimit = RateLimitInterceptor(requestsPerWindow: 1000)

        let requestChain = InterceptorChain(
            requestInterceptors: [auth, logging, rateLimit]
        )

        let responseChain = InterceptorChain(
            responseInterceptors: [logging, cache, retry]
        )

        // Measure performance of sequential requests
        let startTime = Date()

        for _ in 0 ..< 100 {
            var request = makeRequest()
            let requestContext = makeContext()

            _ = try await requestChain.executeRequestInterceptors(
                request: &request,
                context: requestContext
            )

            let response = makeResponse()
            let responseContext = makeContext()

            _ = try await responseChain.executeResponseInterceptors(
                response: response,
                context: responseContext
            )
        }

        let elapsed = Date().timeIntervalSince(startTime)

        // Verify performance is acceptable (100 requests in reasonable time)
        XCTAssertLessThan(elapsed, 5.0, "100 requests should complete in under 5 seconds")
    }
}

// MARK: - Test Helper: IntegrationTokenStorage

private final class IntegrationTokenStorage: @unchecked Sendable {
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
