import Testing
import Foundation
@testable import Networking

@Suite("Caching System Tests")
struct CachingTests {
  // MARK: - Test Data Setup

  private func createTestRequest(url: String = "https://api.example.com/test") throws -> HTTPRequest {
    try HTTPRequest {
      GET(url)
      Header("Authorization", "Bearer test-token")
    }
  }

  private func createTestResponse(
    status: HTTPStatus = .ok,
    headers: [String: String] = [:],
    body: String = "test response body"
  ) -> HTTPResponse {
    let request = HTTPRequest(method: .get, url: URL(string: "https://api.example.com/test")!)
    return HTTPResponse(
      request: request,
      status: status,
      headers: headers,
      body: body.data(using: .utf8)
    )
  }

  private func createTestClient() -> HTTPClient {
    // Mock HTTP client for testing
    CachingTestMockHTTPClient()
  }

  // MARK: - Basic Cache Entry Tests

  @Test("Cache entry creation and expiration")
  func testCacheEntryBasics() async throws {
    let response = createTestResponse()
    let entry = CachingMiddleware.CacheEntry(
      response: response,
      ttl: 300.0,
      etag: "test-etag",
      lastModified: "Wed, 21 Oct 2015 07:28:00 GMT"
    )

    #expect(entry.response.status == .ok)
    #expect(entry.etag == "test-etag")
    #expect(entry.lastModified == "Wed, 21 Oct 2015 07:28:00 GMT")
    #expect(!entry.isExpired)  // Should not be expired immediately
    #expect(entry.age >= 0)
    #expect(entry.age < 1.0)  // Should be very small initially
  }

  @Test("Cache entry expiration behavior")
  func testCacheEntryExpiration() async throws {
    let response = createTestResponse()

    // Create entry with very short TTL
    let entry = CachingMiddleware.CacheEntry(
      response: response,
      ttl: 0.001,  // 1ms
      etag: "test-etag"
    )

    // Wait for expiration
    try await Task.sleep(nanoseconds: 10_000_000)  // 10ms

    #expect(entry.isExpired)
    #expect(entry.age > 0.005)  // At least 5ms old
  }

  // MARK: - Memory Cache Storage Tests

  @Test("Memory cache basic operations")
  func testMemoryCacheBasicOperations() async throws {
    let cache = MemoryCacheStorage(maxSize: 10)
    let key = "test-key"
    let response = createTestResponse()
    let entry = CachingMiddleware.CacheEntry(
      response: response,
      ttl: 300.0
    )

    // Test set and get
    await cache.set(key, entry: entry)
    let retrieved = await cache.get(key)

    #expect(retrieved != nil)
    #expect(retrieved?.response.status == .ok)
    #expect(await cache.size == 1)

    // Test remove
    await cache.remove(key)
    let removedEntry = await cache.get(key)
    #expect(removedEntry == nil)
    #expect(await cache.size == 0)
  }

  @Test("Memory cache size limits")
  func testMemoryCacheSizeLimits() async throws {
    let cache = MemoryCacheStorage(maxSize: 2)

    // Add entries beyond limit
    for i in 0..<5 {
      let key = "key-\(i)"
      let response = createTestResponse()
      let entry = CachingMiddleware.CacheEntry(
        response: response,
        ttl: 300.0
      )
      await cache.set(key, entry: entry)
    }

    // Cache should enforce size limit
    #expect(await cache.size <= 2)

    // Newest entries should be preserved (LRU approximation)
    let lastEntry = await cache.get("key-4")
    #expect(lastEntry != nil)
  }

  @Test("Memory cache expired entry cleanup")
  func testMemoryCacheExpiredCleanup() async throws {
    let cache = MemoryCacheStorage()
    let key = "expired-key"
    let response = createTestResponse()
    let entry = CachingMiddleware.CacheEntry(
      response: response,
      ttl: 0.001  // Very short TTL
    )

    await cache.set(key, entry: entry)

    // Wait for expiration
    try await Task.sleep(nanoseconds: 10_000_000)  // 10ms

    // Entry should be automatically removed when accessed
    let retrievedEntry = await cache.get(key)
    #expect(retrievedEntry == nil)

    // Manual cleanup should also work
    await cache.set(
      "test-key",
      entry: CachingMiddleware.CacheEntry(
        response: response,
        ttl: 0.001
      )
    )
    try await Task.sleep(nanoseconds: 10_000_000)

    await cache.removeExpired()
    let cleanedEntry = await cache.get("test-key")
    #expect(cleanedEntry == nil)
  }

  // MARK: - Advanced Memory Cache Tests

  @Test("Advanced memory cache with LRU policy")
  func testAdvancedMemoryCacheLRU() async throws {
    let cache = AdvancedMemoryCacheStorage(
      policy: .lru,
      sizePolicy: .maxEntries(3)
    )

    // Fill cache to capacity
    for i in 0..<3 {
      let key = "key-\(i)"
      let response = createTestResponse()
      let entry = CachingMiddleware.CacheEntry(response: response, ttl: 300.0)
      await cache.set(key, entry: entry)
    }

    // Access first entry to make it recently used
    _ = await cache.get("key-0")

    // Add another entry, should evict key-1 (least recently used)
    let response = createTestResponse()
    let entry = CachingMiddleware.CacheEntry(response: response, ttl: 300.0)
    await cache.set("key-3", entry: entry)

    // key-0 and key-2, key-3 should exist, key-1 should be evicted
    #expect(await cache.get("key-0") != nil)
    #expect(await cache.get("key-1") == nil)  // Should be evicted
    #expect(await cache.get("key-2") != nil)
    #expect(await cache.get("key-3") != nil)
  }

  @Test("Advanced memory cache tag-based invalidation")
  func testAdvancedMemoryCacheTagInvalidation() async throws {
    let cache = AdvancedMemoryCacheStorage()
    let response = createTestResponse()

    // Set entries with different tags
    let entry1 = CachingMiddleware.CacheEntry(response: response, ttl: 300.0)
    let entry2 = CachingMiddleware.CacheEntry(response: response, ttl: 300.0)
    let entry3 = CachingMiddleware.CacheEntry(response: response, ttl: 300.0)

    await cache.set("user-1", entry: entry1, tags: ["user", "profile"])
    await cache.set("user-2", entry: entry2, tags: ["user", "settings"])
    await cache.set("product-1", entry: entry3, tags: ["product"])

    // Invalidate by user tag
    await cache.removeByTags(["user"])

    // User entries should be gone, product should remain
    #expect(await cache.get("user-1") == nil)
    #expect(await cache.get("user-2") == nil)
    #expect(await cache.get("product-1") != nil)
  }

  @Test("Advanced memory cache metrics")
  func testAdvancedMemoryCacheMetrics() async throws {
    let cache = AdvancedMemoryCacheStorage()
    let response = createTestResponse()
    let entry = CachingMiddleware.CacheEntry(response: response, ttl: 300.0)

    // Initial metrics
    var metrics = await cache.getMetrics()
    #expect(metrics.hitCount == 0)
    #expect(metrics.missCount == 0)

    // Add entry and access it
    await cache.set("test-key", entry: entry)
    _ = await cache.get("test-key")  // Hit
    _ = await cache.get("missing-key")  // Miss

    // Check updated metrics
    metrics = await cache.getMetrics()
    #expect(metrics.hitCount == 1)
    #expect(metrics.missCount == 1)
    #expect(metrics.hitRatio == 0.5)
    #expect(metrics.size == 1)
  }

  // MARK: - Caching Middleware Tests

  @Test("Caching middleware basic functionality")
  func testCachingMiddlewareBasic() async throws {
    let client = createTestClient()
    let storage = MemoryCacheStorage()
    let configuration = CachingMiddleware.Configuration(
      defaultTTL: 300.0
    )

    let middleware = CachingMiddleware(
      configuration: configuration,
      storage: storage,
      client: client
    )

    let request = try createTestRequest()
    let response = createTestResponse()

    // Process response (should cache it)
    let processedResponse = try await middleware.processResponse(response, for: request)
    #expect(processedResponse.status == .ok)

    // Check if cached
    let cachedEntry = await middleware.getCachedEntry(for: request)
    #expect(cachedEntry != nil)
    #expect(cachedEntry?.response.status == .ok)
  }

  @Test("Caching middleware with cache control headers")
  func testCachingMiddlewareWithCacheControl() async throws {
    let client = createTestClient()
    let storage = MemoryCacheStorage()
    let configuration = CachingMiddleware.Configuration()

    let middleware = CachingMiddleware(
      configuration: configuration,
      storage: storage,
      client: client
    )

    let request = try createTestRequest()

    // Test response with no-cache directive
    let noCacheResponse = createTestResponse(headers: [
      "Cache-Control": "no-cache"
    ])

    _ = try await middleware.processResponse(noCacheResponse, for: request)
    let cachedEntry = await middleware.getCachedEntry(for: request)
    #expect(cachedEntry == nil)  // Should not be cached

    // Test response with max-age directive
    let maxAgeResponse = createTestResponse(headers: [
      "Cache-Control": "max-age=600"
    ])

    _ = try await middleware.processResponse(maxAgeResponse, for: request)
    let cachedMaxAgeEntry = await middleware.getCachedEntry(for: request)
    #expect(cachedMaxAgeEntry != nil)  // Should be cached with specific TTL
  }

  @Test("Caching middleware conditional requests")
  func testCachingMiddlewareConditionalRequests() async throws {
    let client = createTestClient()
    let storage = MemoryCacheStorage()
    let configuration = CachingMiddleware.Configuration(
      useConditionalRequests: true
    )

    let middleware = CachingMiddleware(
      configuration: configuration,
      storage: storage,
      client: client
    )

    let request = try createTestRequest()
    let response = createTestResponse(headers: [
      "ETag": "\"123abc\"",
      "Last-Modified": "Wed, 21 Oct 2015 07:28:00 GMT",
    ])

    // Cache the response
    _ = try await middleware.processResponse(response, for: request)

    // Request should be modified with conditional headers
    let modifiedRequest = try await middleware.modifyRequest(request)

    #expect(modifiedRequest.headers["If-None-Match"] == "\"123abc\"")
    #expect(modifiedRequest.headers["If-Modified-Since"] == "Wed, 21 Oct 2015 07:28:00 GMT")
  }

  @Test("Caching middleware 304 Not Modified handling")
  func testCachingMiddleware304Handling() async throws {
    let client = createTestClient()
    let storage = MemoryCacheStorage()
    let configuration = CachingMiddleware.Configuration()

    let middleware = CachingMiddleware(
      configuration: configuration,
      storage: storage,
      client: client
    )

    let request = try createTestRequest()
    let originalResponse = createTestResponse(
      body: "original content"
    )

    // Cache original response
    _ = try await middleware.processResponse(originalResponse, for: request)

    // Process 304 response
    let notModifiedResponse = createTestResponse(
      status: HTTPStatus(rawValue: 304),
      body: ""
    )

    let finalResponse = try await middleware.processResponse(notModifiedResponse, for: request)

    // Should return the cached content
    #expect(finalResponse.status == .ok)
    let bodyString = String(data: finalResponse.body ?? Data(), encoding: .utf8)
    #expect(bodyString == "original content")
  }

  // MARK: - Cache Metadata and Intelligence Tests

  @Test("Cache metadata extraction and intelligent key generation")
  func testCacheMetadataAndIntelligentKeys() async throws {
    let metadata = CacheMetadata(
      ttl: 600.0,
      tags: ["user", "profile"],
      customKey: "custom-user-profile-key",
      isInvalidating: false
    )

    let request = try createTestRequest()

    // Test intelligent key generation
    let intelligentKey = CachingMiddleware.Configuration.defaultIntelligentCacheKey(
      request,
      metadata
    )
    #expect(intelligentKey == "custom-user-profile-key")  // Should use custom key

    // Test with metadata but no custom key
    let metadataWithoutKey = CacheMetadata(
      ttl: 600.0,
      tags: ["user"],
      customKey: nil
    )

    let generatedKey = CachingMiddleware.Configuration.defaultIntelligentCacheKey(
      request,
      metadataWithoutKey
    )
    #expect(generatedKey.contains("GET"))
    #expect(generatedKey.contains("api.example.com"))
    #expect(!generatedKey.isEmpty)
  }

  @Test("Cache invalidation with metadata")
  func testCacheInvalidationWithMetadata() async throws {
    let storage = AdvancedMemoryCacheStorage()
    let response = createTestResponse()

    // Set up cached entries with tags
    let userEntry = CachingMiddleware.CacheEntry(response: response, ttl: 300.0)
    let productEntry = CachingMiddleware.CacheEntry(response: response, ttl: 300.0)

    await storage.set("user-profile", entry: userEntry, tags: ["user", "profile"])
    await storage.set("product-list", entry: productEntry, tags: ["product"])

    // Simulate invalidation metadata
    let invalidationMetadata = CacheMetadata(
      isInvalidating: true,
      invalidationTags: ["user"],
      invalidationPattern: "user-*"
    )

    // Test tag-based invalidation
    if !invalidationMetadata.invalidationTags.isEmpty {
      await storage.removeByTags(invalidationMetadata.invalidationTags)
    }

    // User entry should be invalidated
    #expect(await storage.get("user-profile") == nil)
    #expect(await storage.get("product-list") != nil)
  }

  // MARK: - Performance and Stress Tests

  @Test("Cache performance under concurrent access")
  func testCachePerformanceConcurrentAccess() async throws {
    let cache = AdvancedMemoryCacheStorage(
      policy: .lru,
      sizePolicy: .maxEntries(1000)
    )

    let response = createTestResponse()
    let entry = CachingMiddleware.CacheEntry(response: response, ttl: 300.0)

    // Concurrent writes
    await withTaskGroup(of: Void.self) { group in
      for i in 0..<100 {
        group.addTask {
          let key = "concurrent-key-\(i)"
          await cache.set(key, entry: entry)
        }
      }
    }

    // Concurrent reads
    var hitCount = 0
    await withTaskGroup(of: Bool.self) { group in
      for i in 0..<100 {
        group.addTask {
          let key = "concurrent-key-\(i)"
          let result = await cache.get(key)
          return result != nil
        }
      }

      for await hit in group {
        if hit {
          hitCount += 1
        }
      }
    }

    // Most entries should be accessible
    #expect(hitCount >= 90)  // Allow for some eviction due to size limits

    // Check metrics
    let metrics = await cache.getMetrics()
    #expect(metrics.hitCount >= 90)
  }

  @Test("Memory cache eviction performance")
  func testMemoryCacheEvictionPerformance() async throws {
    let cache = AdvancedMemoryCacheStorage(
      policy: .lru,
      sizePolicy: .maxEntries(100)
    )

    let response = createTestResponse()

    // Fill cache beyond capacity
    let startTime = Date()
    for i in 0..<500 {
      let key = "perf-key-\(i)"
      let entry = CachingMiddleware.CacheEntry(response: response, ttl: 300.0)
      await cache.set(key, entry: entry)
    }
    let duration = Date().timeIntervalSince(startTime)

    // Should complete in reasonable time (less than 1 second for 500 operations)
    #expect(duration < 1.0)

    // Cache should be at size limit
    let metrics = await cache.getMetrics()
    #expect(metrics.size <= 100)
    #expect(metrics.evictionCount > 0)
  }

  @Test("Cache key normalization and collision handling")
  func testCacheKeyNormalizationAndCollisions() async throws {
    let cache = MemoryCacheStorage()
    let response = createTestResponse()
    let entry = CachingMiddleware.CacheEntry(response: response, ttl: 300.0)

    // URLs that should generate different cache keys
    let request1 = try HTTPRequest { GET("https://api.example.com/users?id=1&name=john") }
    let request2 = try HTTPRequest { GET("https://api.example.com/users?name=john&id=1") }

    let key1 = CachingMiddleware.Configuration.defaultIntelligentCacheKey(request1, nil)
    let key2 = CachingMiddleware.Configuration.defaultIntelligentCacheKey(request2, nil)

    // Keys should be the same for semantically equivalent requests
    // (the intelligent key generator sorts query parameters)
    #expect(key1 == key2)

    // Different URLs should generate different keys
    let request3 = try HTTPRequest { GET("https://api.example.com/products?id=1") }
    let key3 = CachingMiddleware.Configuration.defaultIntelligentCacheKey(request3, nil)

    #expect(key1 != key3)
  }

  // MARK: - Integration Tests

  @Test("End-to-end caching workflow")
  func testEndToEndCachingWorkflow() async throws {
    let client = createTestClient()
    let storage = AdvancedMemoryCacheStorage(
      policy: .lru,
      sizePolicy: .maxEntries(100)
    )
    let configuration = CachingMiddleware.Configuration(
      defaultTTL: 300.0,
      useConditionalRequests: true
    )

    let middleware = CachingMiddleware(
      configuration: configuration,
      storage: storage,
      client: client
    )

    let request = try createTestRequest()
    let response = createTestResponse(
      headers: ["ETag": "\"version1\""],
      body: "initial content"
    )

    // Step 1: First request - cache miss, store response
    let processedResponse1 = try await middleware.processResponse(response, for: request)
    #expect(processedResponse1.status == .ok)

    // Step 2: Second request - should add conditional headers
    let modifiedRequest = try await middleware.modifyRequest(request)
    #expect(modifiedRequest.headers["If-None-Match"] == "\"version1\"")

    // Step 3: Server returns 304 - should return cached content
    let notModifiedResponse = createTestResponse(
      status: HTTPStatus(rawValue: 304),
      body: ""
    )

    let processedResponse2 = try await middleware.processResponse(notModifiedResponse, for: request)
    #expect(processedResponse2.status == .ok)
    let cachedBodyString = String(data: processedResponse2.body ?? Data(), encoding: .utf8)
    #expect(cachedBodyString == "initial content")

    // Step 4: Cache invalidation
    await middleware.clearCache()
    let clearedEntry = await middleware.getCachedEntry(for: request)
    #expect(clearedEntry == nil)

    // Verify metrics
    let metrics = await storage.getMetrics()
    #expect(metrics.hitCount >= 1)
    #expect(metrics.hitRatio > 0.0)
  }

  @Test("Cache behavior with different HTTP methods")
  func testCacheWithDifferentHTTPMethods() async throws {
    let client = createTestClient()
    let storage = MemoryCacheStorage()
    let configuration = CachingMiddleware.Configuration()

    let middleware = CachingMiddleware(
      configuration: configuration,
      storage: storage,
      client: client
    )

    let response = createTestResponse()

    // GET request should be cached
    let getRequest = try HTTPRequest { GET("https://api.example.com/users") }
    _ = try await middleware.processResponse(response, for: getRequest)
    let getCached = await middleware.getCachedEntry(for: getRequest)
    #expect(getCached != nil)

    // POST request should not be cached by default
    let postRequest = try HTTPRequest { POST("https://api.example.com/users") }
    _ = try await middleware.processResponse(response, for: postRequest)
    let postCached = await middleware.getCachedEntry(for: postRequest)
    #expect(postCached == nil)
  }
}

// MARK: - Mock HTTP Client

/// Mock HTTP client for testing
private final class CachingTestMockHTTPClient: HTTPClient {
  func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
    // Return a basic response for testing
    HTTPResponse(
      request: request,
      status: .ok,
      headers: [:],
      body: "mock response".data(using: .utf8)
    )
  }
}

// MARK: - Test Extensions for HTTPStatus

extension HTTPStatus {
  init(rawValue: Int) {
    switch rawValue {
    case 200:
      self = .ok

    case 304:
      self = .notModified

    case 404:
      self = .notFound

    case 500:
      self = .internalServerError

    default:
      self = .ok  // Default for testing
    }
  }
}

extension HTTPStatus {
  static let notModified = HTTPStatus(rawValue: 304)
}
