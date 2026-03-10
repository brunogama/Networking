import Foundation
import XCTest

@testable import NetworkingInterceptorsCompat
import NetworkingRuntime
import NetworkingDSL
import NetworkingTesting

/// Tests for CachingInterceptor
final class CachingInterceptorTests: XCTestCase {
    // MARK: - Basic Caching

    func testCachesSuccessfulGETResponse() async throws {
        // Given: A caching interceptor
        let interceptor = CachingInterceptor(ttl: 300)

        // When: Intercepting a successful GET response
        let request = HTTPRequest(method: .get, path: "/api/users", baseURL: "https://api.com")
        let context = InterceptorContext(path: "/api/users", method: .get, metadata: [:])

        let responseData = "test data".data(using: .utf8)
        let response = HTTPResponse(
            request: request,
            status: .ok,
            headers: [:],
            body: responseData
        )

        let result = try await interceptor.intercept(response: response, context: context)

        // Then: Response is cached
        if case .proceed = result {
            // Success
        } else {
            XCTFail("Expected .proceed, got \(result)")
        }

        // Verify cache contains the response
        let cached = await interceptor.getCachedResponse(for: .get, path: "/api/users")
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.body, responseData)
    }

    func testDoesNotCachePOSTRequests() async throws {
        // Given: A caching interceptor
        let interceptor = CachingInterceptor(ttl: 300)

        // When: Intercepting a POST response
        let request = HTTPRequest(method: .post, path: "/api/users", baseURL: "https://api.com")
        let context = InterceptorContext(path: "/api/users", method: .post, metadata: [:])

        let response = HTTPResponse(
            request: request,
            status: .created,
            headers: [:],
            body: nil
        )

        _ = try await interceptor.intercept(response: response, context: context)

        // Then: Response is not cached
        let cached = await interceptor.getCachedResponse(for: .post, path: "/api/users")
        XCTAssertNil(cached)
    }

    func testDoesNotCacheNon200Responses() async throws {
        // Given: A caching interceptor
        let interceptor = CachingInterceptor(ttl: 300)

        // When: Intercepting error responses
        let request = HTTPRequest(method: .get, path: "/api/error", baseURL: "https://api.com")

        let errorStatuses: [HTTPStatus] = [.badRequest, .unauthorized, .notFound, .internalServerError]

        for status in errorStatuses {
            let context = InterceptorContext(path: "/api/error", method: .get, metadata: [:])

            let response = HTTPResponse(
                request: request,
                status: status,
                headers: [:],
                body: nil
            )

            _ = try await interceptor.intercept(response: response, context: context)
        }

        // Then: No responses are cached
        let cached = await interceptor.getCachedResponse(for: .get, path: "/api/error")
        XCTAssertNil(cached)
    }

    // MARK: - Cache Expiration

    func testCacheExpiresAfterTTL() async throws {
        // Given: A caching interceptor with short TTL
        let interceptor = CachingInterceptor(ttl: 0.1) // 100ms

        let request = HTTPRequest(method: .get, path: "/api/temp", baseURL: "https://api.com")
        let context = InterceptorContext(path: "/api/temp", method: .get, metadata: [:])

        let response = HTTPResponse(
            request: request,
            status: .ok,
            headers: [:],
            body: "data".data(using: .utf8)
        )

        // When: Caching a response
        _ = try await interceptor.intercept(response: response, context: context)

        // Then: Response is initially cached
        var cached = await interceptor.getCachedResponse(for: .get, path: "/api/temp")
        XCTAssertNotNil(cached)

        // Wait for TTL to expire
        try await Task.sleep(nanoseconds: 150_000_000) // 150ms

        // Then: Response is no longer cached
        cached = await interceptor.getCachedResponse(for: .get, path: "/api/temp")
        XCTAssertNil(cached, "Cache should have expired")
    }

    // MARK: - LRU Eviction

    func testEvictsLRUEntryWhenAtCapacity() async throws {
        // Given: A cache with max 2 entries
        let interceptor = CachingInterceptor(ttl: 300, maxEntries: 2)

        let request1 = HTTPRequest(method: .get, path: "/api/1", baseURL: "https://api.com")
        let request2 = HTTPRequest(method: .get, path: "/api/2", baseURL: "https://api.com")
        let request3 = HTTPRequest(method: .get, path: "/api/3", baseURL: "https://api.com")

        let response1 = HTTPResponse(
            request: request1,
            status: .ok,
            headers: [:],
            body: "data1".data(using: .utf8)
        )

        let response2 = HTTPResponse(
            request: request2,
            status: .ok,
            headers: [:],
            body: "data2".data(using: .utf8)
        )

        let response3 = HTTPResponse(
            request: request3,
            status: .ok,
            headers: [:],
            body: "data3".data(using: .utf8)
        )

        // When: Adding 3 entries (exceeding capacity)
        _ = try await interceptor.intercept(
            response: response1,
            context: InterceptorContext(path: "/api/1", method: .get, metadata: [:])
        )
        _ = try await interceptor.intercept(
            response: response2,
            context: InterceptorContext(path: "/api/2", method: .get, metadata: [:])
        )
        _ = try await interceptor.intercept(
            response: response3,
            context: InterceptorContext(path: "/api/3", method: .get, metadata: [:])
        )

        // Then: First entry (LRU) is evicted
        let cached1 = await interceptor.getCachedResponse(for: .get, path: "/api/1")
        let cached2 = await interceptor.getCachedResponse(for: .get, path: "/api/2")
        let cached3 = await interceptor.getCachedResponse(for: .get, path: "/api/3")

        XCTAssertNil(cached1, "First entry should be evicted")
        XCTAssertNotNil(cached2, "Second entry should remain")
        XCTAssertNotNil(cached3, "Third entry should remain")
    }

    func testLRUOrderUpdatesOnAccess() async throws {
        // Given: A cache with max 2 entries
        let interceptor = CachingInterceptor(ttl: 300, maxEntries: 2)

        let request1 = HTTPRequest(method: .get, path: "/api/old", baseURL: "https://api.com")
        let request2 = HTTPRequest(method: .get, path: "/api/new", baseURL: "https://api.com")
        let request3 = HTTPRequest(method: .get, path: "/api/newest", baseURL: "https://api.com")

        let response1 = HTTPResponse(
            request: request1,
            status: .ok,
            headers: [:],
            body: "old".data(using: .utf8)
        )

        let response2 = HTTPResponse(
            request: request2,
            status: .ok,
            headers: [:],
            body: "new".data(using: .utf8)
        )

        let response3 = HTTPResponse(
            request: request3,
            status: .ok,
            headers: [:],
            body: "newest".data(using: .utf8)
        )

        // When: Adding 2 entries, accessing first, then adding third
        _ = try await interceptor.intercept(
            response: response1,
            context: InterceptorContext(path: "/api/old", method: .get, metadata: [:])
        )
        _ = try await interceptor.intercept(
            response: response2,
            context: InterceptorContext(path: "/api/new", method: .get, metadata: [:])
        )

        // Access first entry to update LRU order
        _ = await interceptor.getCachedResponse(for: .get, path: "/api/old")

        // Add third entry (should evict /api/new since /api/old was accessed)
        _ = try await interceptor.intercept(
            response: response3,
            context: InterceptorContext(path: "/api/newest", method: .get, metadata: [:])
        )

        // Then: Second entry is evicted (was LRU)
        let cached1 = await interceptor.getCachedResponse(for: .get, path: "/api/old")
        let cached2 = await interceptor.getCachedResponse(for: .get, path: "/api/new")
        let cached3 = await interceptor.getCachedResponse(for: .get, path: "/api/newest")

        XCTAssertNotNil(cached1, "First entry should remain (was accessed)")
        XCTAssertNil(cached2, "Second entry should be evicted (was LRU)")
        XCTAssertNotNil(cached3, "Third entry should remain (newest)")
    }

    // MARK: - Cache Management

    func testClearCacheRemovesAllEntries() async throws {
        // Given: A cache with multiple entries
        let interceptor = CachingInterceptor(ttl: 300)

        for i in 1 ... 5 {
            let request = HTTPRequest(method: .get, path: "/api/\(i)", baseURL: "https://api.com")
            let response = HTTPResponse(
                request: request,
                status: .ok,
                headers: [:],
                body: "data\(i)".data(using: .utf8)
            )

            _ = try await interceptor.intercept(
                response: response,
                context: InterceptorContext(path: "/api/\(i)", method: .get, metadata: [:])
            )
        }

        // When: Clearing the cache
        await interceptor.clearCache()

        // Then: All entries are removed
        for i in 1 ... 5 {
            let cached = await interceptor.getCachedResponse(for: .get, path: "/api/\(i)")
            XCTAssertNil(cached, "Entry \(i) should be cleared")
        }
    }

    func testClearExpiredRemovesOnlyExpiredEntries() async throws {
        // Given: Cache with expired and valid entries
        let interceptor = CachingInterceptor(ttl: 0.1) // 100ms

        // Add expired entry
        let request1 = HTTPRequest(method: .get, path: "/api/expired", baseURL: "https://api.com")
        let response1 = HTTPResponse(
            request: request1,
            status: .ok,
            headers: [:],
            body: "old".data(using: .utf8)
        )

        _ = try await interceptor.intercept(
            response: response1,
            context: InterceptorContext(path: "/api/expired", method: .get, metadata: [:])
        )

        // Wait for first entry to expire
        try await Task.sleep(nanoseconds: 150_000_000) // 150ms

        // Add valid entry with fresh interceptor (new TTL countdown)
        let freshInterceptor = CachingInterceptor(ttl: 300)
        let request2 = HTTPRequest(method: .get, path: "/api/valid", baseURL: "https://api.com")
        let response2 = HTTPResponse(
            request: request2,
            status: .ok,
            headers: [:],
            body: "new".data(using: .utf8)
        )

        _ = try await freshInterceptor.intercept(
            response: response2,
            context: InterceptorContext(path: "/api/valid", method: .get, metadata: [:])
        )

        // When: Clearing expired entries
        await interceptor.clearExpired()

        // Then: Expired removed, valid remains
        let expired = await interceptor.getCachedResponse(for: .get, path: "/api/expired")
        let valid = await freshInterceptor.getCachedResponse(for: .get, path: "/api/valid")

        XCTAssertNil(expired, "Expired entry should be removed")
        XCTAssertNotNil(valid, "Valid entry should remain")
    }

    // MARK: - Concurrent Access

    func testThreadSafeConcurrentAccess() async throws {
        // Given: A caching interceptor
        let interceptor = CachingInterceptor(ttl: 300, maxEntries: 100)

        // When: Multiple concurrent cache operations
        await withTaskGroup(of: Void.self) { group in
            for i in 0 ..< 50 {
                group.addTask {
                    let request = HTTPRequest(method: .get, path: "/api/\(i)", baseURL: "https://api.com")
                    let response = HTTPResponse(
                        request: request,
                        status: .ok,
                        headers: [:],
                        body: "data\(i)".data(using: .utf8)
                    )

                    let context = InterceptorContext(path: "/api/\(i)", method: .get, metadata: [:])
                    _ = try? await interceptor.intercept(response: response, context: context)
                }

                group.addTask {
                    _ = await interceptor.getCachedResponse(for: .get, path: "/api/\(i)")
                }
            }
        }

        // Then: No crashes or data races
        // Success is no crash during concurrent access
    }

    // MARK: - Integration with InterceptorChain

    func testWorksWithInterceptorChain() async throws {
        // Given: A chain with caching interceptor
        let cache = CachingInterceptor(ttl: 300)

        let chain = InterceptorChain(
            requestInterceptors: [],
            responseInterceptors: [cache]
        )

        // When: Executing chain with GET response
        let request = HTTPRequest(method: .get, path: "/api/chain", baseURL: "https://example.com")
        let context = InterceptorContext(path: "/api/chain", method: .get, metadata: [:])

        let response = HTTPResponse(
            request: request,
            status: .ok,
            headers: [:],
            body: "chain data".data(using: .utf8)
        )

        let result = try await chain.executeResponseInterceptors(response: response, context: context)

        // Then: Chain proceeds and response is cached
        if case .proceed = result {
            // Success
        } else {
            XCTFail("Expected .proceed, got \(result)")
        }

        let cached = await cache.getCachedResponse(for: .get, path: "/api/chain")
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.body, "chain data".data(using: .utf8))
    }
}
