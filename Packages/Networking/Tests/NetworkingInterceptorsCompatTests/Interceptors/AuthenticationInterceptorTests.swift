@testable import NetworkingInterceptorsCompat
import NetworkingRuntime
import NetworkingDSL
import NetworkingTesting
import XCTest

/// Tests for AuthenticationInterceptor
final class AuthenticationInterceptorTests: XCTestCase {
    // MARK: - Basic Authentication

    func testAddsAuthorizationHeaderWithBearerToken() async throws {
        // Given: An interceptor with a static token
        let token = "test-access-token-12345"
        let interceptor = AuthenticationInterceptor.bearer(BearerTokenValue(token))

        // When: Intercepting a request
        var request = HTTPRequest(method: .get, path: "/api/data", baseURL: "https://example.com")
        let context = InterceptorContext(
            path: "/api/data",
            method: .get,
            metadata: [:]
        )

        let result = try await interceptor.intercept(request: &request, context: context)

        // Then: Authorization header is added
        if case .proceed = result {
            // Success
        } else {
            XCTFail("Expected .proceed, got \(result)")
        }
        XCTAssertEqual(request.headers["Authorization"], "Bearer \(token)")
    }

    func testStaticTokenProvider() async throws {
        // Given: An interceptor with static token convenience initializer
        let token = "static-token"
        let interceptor = AuthenticationInterceptor.bearer(BearerTokenValue(token))

        // When: Intercepting a request
        var request = HTTPRequest(method: .get, path: "/test", baseURL: "https://api.example.com")
        let context = InterceptorContext(path: "/test", method: .get, metadata: [:])

        _ = try await interceptor.intercept(request: &request, context: context)

        // Then: Token is correctly added
        XCTAssertEqual(request.headers["Authorization"], "Bearer static-token")
    }

    // MARK: - Dynamic Token Provider

    func testDynamicTokenProvider() async throws {
        // Given: An interceptor with a dynamic token provider using an actor for thread-safety
        actor TokenCounter {
            private var count = 0

            func next() -> Int {
                count += 1
                return count
            }

            func getCount() -> Int {
                count
            }
        }

        let counter = TokenCounter()
        let interceptor = AuthenticationInterceptor { () async throws -> BearerTokenValue in
            let count = await counter.next()
            return BearerTokenValue("dynamic-token-\(count)")
        }

        // When: Intercepting multiple requests
        var request1 = HTTPRequest(method: .get, path: "/endpoint1", baseURL: "https://api.com")
        var request2 = HTTPRequest(method: .get, path: "/endpoint2", baseURL: "https://api.com")
        let context = InterceptorContext(path: "/test", method: .get, metadata: [:])

        _ = try await interceptor.intercept(request: &request1, context: context)
        _ = try await interceptor.intercept(request: &request2, context: context)

        // Then: Token provider is called for each request
        let finalCount = await counter.getCount()
        XCTAssertEqual(finalCount, 2)
        XCTAssertEqual(request1.headers["Authorization"], "Bearer dynamic-token-1")
        XCTAssertEqual(request2.headers["Authorization"], "Bearer dynamic-token-2")
    }

    func testAsyncTokenProvider() async throws {
        // Given: An interceptor with an async token provider
        let interceptor = AuthenticationInterceptor { () async throws -> BearerTokenValue in
            // Simulate async token fetch
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            return BearerTokenValue("async-fetched-token")
        }

        // When: Intercepting a request
        var request = HTTPRequest(method: .post, path: "/data", baseURL: "https://api.example.com")
        let context = InterceptorContext(path: "/data", method: .post, metadata: [:])

        let result = try await interceptor.intercept(request: &request, context: context)

        // Then: Token is fetched asynchronously
        if case .proceed = result {
            // Success
        } else {
            XCTFail("Expected .proceed, got \(result)")
        }
        XCTAssertEqual(request.headers["Authorization"], "Bearer async-fetched-token")
    }

    // MARK: - Error Handling

    func testTokenProviderErrorPropagates() async throws {
        // Given: An interceptor with a failing token provider
        struct TokenError: Error, Equatable {}
        let interceptor = AuthenticationInterceptor { () async throws -> BearerTokenValue in
            throw TokenError()
        }

        // When: Intercepting a request
        var request = HTTPRequest(method: .get, path: "/protected", baseURL: "https://api.com")
        let context = InterceptorContext(path: "/protected", method: .get, metadata: [:])

        // Then: Error propagates
        do {
            _ = try await interceptor.intercept(request: &request, context: context)
            XCTFail("Expected error to be thrown")
        } catch let error as TokenError {
            // Success - error propagated correctly
            XCTAssertEqual(error, TokenError())
        } catch {
            XCTFail("Expected TokenError, got \(error)")
        }
    }

    // MARK: - Integration with InterceptorChain

    func testAuthInterceptorInChain() async throws {
        // Given: An interceptor chain with auth interceptor
        let token = "chain-test-token"
        let authInterceptor = AuthenticationInterceptor.bearer(BearerTokenValue(token))

        let chain = InterceptorChain(
            requestInterceptors: [authInterceptor],
            responseInterceptors: []
        )

        // When: Executing request interceptors
        var request = HTTPRequest(method: .get, path: "/api/users", baseURL: "https://example.com")
        let context = InterceptorContext(path: "/api/users", method: .get, metadata: [:])

        let result = try await chain.executeRequestInterceptors(request: &request, context: context)

        // Then: Request is modified with auth header
        if case .proceed = result {
            // Success
        } else {
            XCTFail("Expected .proceed, got \(result)")
        }
        XCTAssertEqual(request.headers["Authorization"], "Bearer chain-test-token")
    }

    // MARK: - Header Preservation

    func testPreservesExistingHeaders() async throws {
        // Given: A request with existing headers
        var request = HTTPRequest(method: .post, path: "/data", baseURL: "https://api.example.com")
        request.addHeader(name: "Content-Type", value: "application/json")
        request.addHeader(name: "Accept", value: "application/json")

        let interceptor = AuthenticationInterceptor.bearer("preserve-test-token")
        let context = InterceptorContext(path: "/data", method: .post, metadata: [:])

        // When: Adding authentication
        _ = try await interceptor.intercept(request: &request, context: context)

        // Then: Existing headers are preserved
        XCTAssertEqual(request.headers["Content-Type"], "application/json")
        XCTAssertEqual(request.headers["Accept"], "application/json")
        XCTAssertEqual(request.headers["Authorization"], "Bearer preserve-test-token")
    }

    func testOverwritesExistingAuthorizationHeader() async throws {
        // Given: A request with an existing Authorization header
        var request = HTTPRequest(method: .get, path: "/secure", baseURL: "https://api.com")
        request.addHeader(name: "Authorization", value: "Bearer old-token")

        let interceptor = AuthenticationInterceptor.bearer("new-token")
        let context = InterceptorContext(path: "/secure", method: .get, metadata: [:])

        // When: Adding new authentication
        _ = try await interceptor.intercept(request: &request, context: context)

        // Then: Old authorization is replaced
        XCTAssertEqual(request.headers["Authorization"], "Bearer new-token")
    }
}
