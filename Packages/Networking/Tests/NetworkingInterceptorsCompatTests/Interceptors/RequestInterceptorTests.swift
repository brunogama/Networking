@testable import NetworkingInterceptorsCompat
import NetworkingRuntime
import NetworkingDSL
import NetworkingTesting
import XCTest

final class RequestInterceptorTests: XCTestCase {
    // MARK: - Mock Interceptors

    struct HeaderAddingInterceptor: RequestInterceptor {
        let headerName: String
        let headerValue: String

        func intercept(
            request: inout HTTPRequest,
            context _: InterceptorContext
        ) async throws -> InterceptorResult {
            request = HTTPRequest(
                method: request.method,
                url: request.url,
                headers: request.headers.merging([headerName: headerValue]) { _, new in new },
                body: request.body,
                timeout: request.timeout
            )
            return .proceed
        }
    }

    struct CachingInterceptor: RequestInterceptor {
        let cachedResponse: HTTPResponse?

        func intercept(
            request _: inout HTTPRequest,
            context _: InterceptorContext
        ) async throws -> InterceptorResult {
            if let cached = cachedResponse {
                return .shortCircuit(cached)
            }
            return .proceed
        }
    }

    struct PathFilteringInterceptor: RequestInterceptor {
        let allowedPath: String
        var callCount = 0

        func intercept(
            request _: inout HTTPRequest,
            context: InterceptorContext
        ) async throws -> InterceptorResult {
            if context.path == allowedPath {
                return .proceed
            }
            return .proceed
        }
    }

    struct AsyncDelayInterceptor: RequestInterceptor {
        let delayNanoseconds: UInt64

        func intercept(
            request _: inout HTTPRequest,
            context _: InterceptorContext
        ) async throws -> InterceptorResult {
            try await Task.sleep(nanoseconds: delayNanoseconds)
            return .proceed
        }
    }

    // MARK: - Helper Methods

    func makeRequest() -> HTTPRequest {
        HTTPRequest(
            method: .get,
            url: URL(string: "https://api.example.com/users")!
        )
    }

    func makeContext(
        path: String = "/users",
        method: HTTPMethod = .get,
        attemptCount: Int = 0
    ) -> InterceptorContext {
        InterceptorContext(path: path, method: method, attemptCount: attemptCount)
    }

    // MARK: - Request Modification Tests

    func testInterceptorCanAddHeaders() async throws {
        let interceptor = HeaderAddingInterceptor(
            headerName: "Authorization",
            headerValue: "Bearer token123"
        )

        var request = makeRequest()
        let context = makeContext()

        let result = try await interceptor.intercept(request: &request, context: context)

        XCTAssertEqual(request.headers["Authorization"], "Bearer token123")

        if case .proceed = result {
            // Expected
        } else {
            XCTFail("Expected .proceed result")
        }
    }

    func testInterceptorCanAddMultipleHeaders() async throws {
        let authInterceptor = HeaderAddingInterceptor(
            headerName: "Authorization",
            headerValue: "Bearer token"
        )
        let apiKeyInterceptor = HeaderAddingInterceptor(
            headerName: "X-API-Key",
            headerValue: "key123"
        )

        var request = makeRequest()
        let context = makeContext()

        _ = try await authInterceptor.intercept(request: &request, context: context)
        _ = try await apiKeyInterceptor.intercept(request: &request, context: context)

        XCTAssertEqual(request.headers["Authorization"], "Bearer token")
        XCTAssertEqual(request.headers["X-API-Key"], "key123")
    }

    func testInterceptorPreservesExistingHeaders() async throws {
        var request = HTTPRequest(
            method: .get,
            url: URL(string: "https://api.example.com/users")!,
            headers: ["Content-Type": "application/json"]
        )

        let interceptor = HeaderAddingInterceptor(
            headerName: "Authorization",
            headerValue: "Bearer token"
        )
        let context = makeContext()

        _ = try await interceptor.intercept(request: &request, context: context)

        XCTAssertEqual(request.headers["Content-Type"], "application/json")
        XCTAssertEqual(request.headers["Authorization"], "Bearer token")
    }

    // MARK: - Context Usage Tests

    func testInterceptorReceivesPath() async throws {
        nonisolated(unsafe) var receivedPath: String?

        struct PathCapturingInterceptor: RequestInterceptor {
            let onPath: @Sendable (String) -> Void

            func intercept(
                request _: inout HTTPRequest,
                context: InterceptorContext
            ) async throws -> InterceptorResult {
                onPath(context.path)
                return .proceed
            }
        }

        let interceptor = PathCapturingInterceptor { path in
            receivedPath = path
        }

        var request = makeRequest()
        let context = makeContext(path: "/api/users/123")

        _ = try await interceptor.intercept(request: &request, context: context)

        XCTAssertEqual(receivedPath, "/api/users/123")
    }

    func testInterceptorReceivesMethod() async throws {
        nonisolated(unsafe) var receivedMethod: HTTPMethod?

        struct MethodCapturingInterceptor: RequestInterceptor {
            let onMethod: @Sendable (HTTPMethod) -> Void

            func intercept(
                request _: inout HTTPRequest,
                context: InterceptorContext
            ) async throws -> InterceptorResult {
                onMethod(context.method)
                return .proceed
            }
        }

        let interceptor = MethodCapturingInterceptor { method in
            receivedMethod = method
        }

        var request = makeRequest()
        let context = makeContext(method: .post)

        _ = try await interceptor.intercept(request: &request, context: context)

        XCTAssertEqual(receivedMethod?.rawValue, "POST")
    }

    func testInterceptorReceivesAttemptCount() async throws {
        nonisolated(unsafe) var receivedAttemptCount: Int?

        struct AttemptCapturingInterceptor: RequestInterceptor {
            let onAttempt: @Sendable (Int) -> Void

            func intercept(
                request _: inout HTTPRequest,
                context: InterceptorContext
            ) async throws -> InterceptorResult {
                onAttempt(context.attemptCount)
                return .proceed
            }
        }

        let interceptor = AttemptCapturingInterceptor { count in
            receivedAttemptCount = count
        }

        var request = makeRequest()
        let context = makeContext(attemptCount: 3)

        _ = try await interceptor.intercept(request: &request, context: context)

        XCTAssertEqual(receivedAttemptCount, 3)
    }

    // MARK: - Short-Circuit Tests

    func testCacheHitShortCircuits() async throws {
        let cachedResponse = HTTPResponse(
            request: makeRequest(),
            status: HTTPStatus(rawValue: 200),
            body: "cached data".data(using: .utf8)
        )

        let interceptor = CachingInterceptor(cachedResponse: cachedResponse)

        var request = makeRequest()
        let context = makeContext()

        let result = try await interceptor.intercept(request: &request, context: context)

        if case let .shortCircuit(response) = result {
            XCTAssertEqual(String(data: response.body ?? Data(), encoding: .utf8), "cached data")
        } else {
            XCTFail("Expected .shortCircuit result")
        }
    }

    func testCacheMissProceed() async throws {
        let interceptor = CachingInterceptor(cachedResponse: nil)

        var request = makeRequest()
        let context = makeContext()

        let result = try await interceptor.intercept(request: &request, context: context)

        if case .proceed = result {
            // Expected
        } else {
            XCTFail("Expected .proceed result")
        }
    }

    // MARK: - Async Execution Tests

    func testAsyncInterceptorExecutes() async throws {
        let interceptor = AsyncDelayInterceptor(delayNanoseconds: 10_000_000) // 10ms

        var request = makeRequest()
        let context = makeContext()

        let startTime = Date()
        _ = try await interceptor.intercept(request: &request, context: context)
        let duration = Date().timeIntervalSince(startTime)

        XCTAssertGreaterThanOrEqual(duration, 0.01, "Should have delayed at least 10ms")
    }

    // MARK: - Path-Based Filtering Tests

    func testPathBasedFiltering() async throws {
        let interceptor = PathFilteringInterceptor(allowedPath: "/api/users")

        // Test with matching path
        var request1 = makeRequest()
        let context1 = makeContext(path: "/api/users")
        let result1 = try await interceptor.intercept(request: &request1, context: context1)

        if case .proceed = result1 {
            // Expected
        } else {
            XCTFail("Expected .proceed for matching path")
        }

        // Test with non-matching path
        var request2 = makeRequest()
        let context2 = makeContext(path: "/api/posts")
        let result2 = try await interceptor.intercept(request: &request2, context: context2)

        if case .proceed = result2 {
            // Expected
        } else {
            XCTFail("Expected .proceed for non-matching path")
        }
    }

    // MARK: - Metadata Tests

    func testInterceptorCanAccessMetadata() async throws {
        nonisolated(unsafe) var receivedMetadata: [String: AnySendable]?

        struct MetadataCapturingInterceptor: RequestInterceptor {
            let onMetadata: @Sendable ([String: AnySendable]) -> Void

            func intercept(
                request _: inout HTTPRequest,
                context: InterceptorContext
            ) async throws -> InterceptorResult {
                onMetadata(context.metadata)
                return .proceed
            }
        }

        let interceptor = MetadataCapturingInterceptor { metadata in
            receivedMetadata = metadata
        }

        var request = makeRequest()
        let context = InterceptorContext(
            path: "/users",
            method: .get,
            attemptCount: 0,
            metadata: ["userId": .string("123"), "isRetry": .bool(true)]
        )

        _ = try await interceptor.intercept(request: &request, context: context)

        XCTAssertEqual(receivedMetadata?["userId"]?.stringValue, "123")
        XCTAssertEqual(receivedMetadata?["isRetry"]?.boolValue, true)
    }

    // MARK: - Sendable Compliance Tests

    func testInterceptorIsSendable() async throws {
        // Interceptors are Sendable by protocol requirement.
        // Compilation of this test suite is sufficient proof of Sendable compliance.
        let interceptor = HeaderAddingInterceptor(
            headerName: "Test",
            headerValue: "Value"
        )
        XCTAssertNotNil(interceptor)
    }
}
