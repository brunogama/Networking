import NetworkingRuntime
import Foundation

/// Response interceptor that caches GET responses in memory with configurable TTL.
///
/// Provides fast, thread-safe response caching to reduce network requests and improve
/// application performance. Only caches successful GET requests (200 OK).
///
/// ## Usage
///
/// ```swift
/// let cache = CachingInterceptor(ttl: 300) // 5 minute cache
///
/// @API(baseURL: "https://api.example.com")
/// @Interceptors([cache])
/// protocol UserAPI {
///   @GET("/users/{id}")
///   func getUser(id: String) async throws -> User
/// }
/// ```
///
/// ## Features
///
/// - Memory-based caching for fast access
/// - Configurable time-to-live (TTL) per cache entry
/// - Thread-safe actor-based cache storage
/// - Automatic cache invalidation on expiration
/// - Only caches GET requests with 200 status
///
/// ## Cache Key
///
/// Cache keys are generated from request method and path:
/// ```
/// "GET:/users/123"
/// ```
@available(
  *,
  deprecated,
  message:
    "CachingInterceptor is a compatibility API. Prefer caching middleware for new runtime behavior."
)
public struct CachingInterceptor: ResponseInterceptor, Sendable {
  /// Time-to-live for cached responses in seconds
  public let ttl: CacheMaxAge

  /// Maximum number of cached entries (default: 100)
  public let maxEntries: CacheEntryLimit

  private let cache: ResponseCache

  /// Creates a caching interceptor.
  ///
  /// - Parameters:
  ///   - ttl: Time-to-live for cache entries in seconds (default: 300 = 5 minutes)
  ///   - maxEntries: Maximum number of cache entries (default: 100)
  public init(
    ttl: CacheMaxAge = CacheMaxAge(rawValue: 300),
    maxEntries: CacheEntryLimit = CacheEntryLimit(rawValue: 100)
  ) {
    self.ttl = ttl
    self.maxEntries = maxEntries
    self.cache = ResponseCache(maxEntries: maxEntries.rawValue)
  }

  // MARK: - ResponseInterceptor

  public func intercept(
    response: HTTPResponse,
    context: InterceptorContext
  ) async throws -> InterceptorResult {
    // Only cache successful GET requests
    guard context.method == .get, response.status == .ok else {
      return .proceed
    }

    // Generate cache key from method and path
    let cacheKey = "\(context.method.rawValue):\(context.path)"

    // Store response in cache with TTL
    let entry = CacheEntry(
      response: response,
      expiresAt: Date().addingTimeInterval(ttl.rawValue)
    )

    await cache.set(entry, forKey: cacheKey)

    return .proceed
  }

  // MARK: - Cache Access

  /// Retrieves a cached response if available and not expired.
  ///
  /// - Parameters:
  ///   - method: HTTP method
  ///   - path: Request path
  /// - Returns: Cached response if available and valid, nil otherwise
  public func getCachedResponse(
    for method: HTTPMethod,
    path: RequestPathPattern
  ) async -> HTTPResponse? {
    let cacheKey = "\(method.rawValue):\(path.rawValue)"
    return await cache.get(forKey: cacheKey)
  }

  package func getCachedResponse(
    for method: HTTPMethod,
    path: String
  ) async -> HTTPResponse? {
    await getCachedResponse(for: method, path: RequestPathPattern(path))
  }

  /// Clears all cached responses.
  public func clearCache() async {
    await cache.clear()
  }

  /// Clears expired cache entries.
  public func clearExpired() async {
    await cache.clearExpired()
  }
}

// MARK: - Cache Storage

/// Actor-based thread-safe cache storage with LRU eviction.
private actor ResponseCache {
  private var entries: [String: CacheEntry] = [:]
  private var accessOrder: [String] = []  // LRU tracking
  private let maxEntries: Int

  init(maxEntries: Int) {
    self.maxEntries = maxEntries
  }

  /// Retrieves a cached response if not expired.
  func get(forKey key: String) -> HTTPResponse? {
    guard let entry = entries[key] else {
      return nil
    }

    // Check expiration
    guard entry.expiresAt > Date() else {
      // Entry expired, remove it
      entries.removeValue(forKey: key)
      accessOrder.removeAll { $0 == key }
      return nil
    }

    // Update access order (move to end = most recently used)
    accessOrder.removeAll { $0 == key }
    accessOrder.append(key)

    return entry.response
  }

  /// Stores a cache entry.
  func set(_ entry: CacheEntry, forKey key: String) {
    // Evict LRU entry if at capacity
    if entries.count >= maxEntries, entries[key] == nil {
      if let lruKey = accessOrder.first {
        entries.removeValue(forKey: lruKey)
        accessOrder.removeFirst()
      }
    }

    entries[key] = entry

    // Update access order
    accessOrder.removeAll { $0 == key }
    accessOrder.append(key)
  }

  /// Clears all cache entries.
  func clear() {
    entries.removeAll()
    accessOrder.removeAll()
  }

  /// Removes expired entries.
  func clearExpired() {
    let now = Date()
    let expiredKeys = entries.compactMap { key, entry in
      entry.expiresAt <= now ? key : nil
    }

    for key in expiredKeys {
      entries.removeValue(forKey: key)
      accessOrder.removeAll { $0 == key }
    }
  }
}

// MARK: - Cache Entry

/// Internal cache entry with expiration.
private struct CacheEntry {
  let response: HTTPResponse
  let expiresAt: Date
}
