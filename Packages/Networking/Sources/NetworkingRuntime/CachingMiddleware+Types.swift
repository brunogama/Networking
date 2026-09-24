import Foundation
import NetworkingCore

extension CachingMiddleware {
  /// A cached response entry with metadata
  public struct CacheEntry: Sendable {
    public let response: HTTPResponse
    public let cachedAt: Date
    public let expiresAt: Date
    public let etag: HTTPHeaderValue?
    public let lastModified: HTTPHeaderValue?

    internal init(
      response: HTTPResponse,
      ttl: CacheMaxAge,
      etag: HTTPHeaderValue? = nil,
      lastModified: HTTPHeaderValue? = nil
    ) {
      let now = Date()
      self.response = response
      self.cachedAt = now
      self.expiresAt = now.addingTimeInterval(ttl.rawValue)
      self.etag = etag
      self.lastModified = lastModified
    }

    /// Returns true if the cache entry has expired
    public var isExpired: CacheExpirationFlag {
      CacheExpirationFlag(Date() > expiresAt)
    }

    /// Returns the age of the cache entry in seconds
    public var age: CacheEntryAge {
      CacheEntryAge(Date().timeIntervalSince(cachedAt))
    }
  }

  /// Protocol for cache storage implementations
  public protocol CacheStorage: Sendable {
    /// Lists stored keys for selective invalidation.
    func keys() async -> [CacheKey]

    /// Retrieves a cached entry for the given key
    func get(_ key: CacheKey) async -> CacheEntry?

    /// Retrieves a cached entry without discarding it when it has expired.
    ///
    /// Conditional requests need the stale response and validators to resolve a 304 response.
    func getForRevalidation(_ key: CacheKey) async -> CacheEntry?

    /// Stores a cache entry with the given key
    func set(_ key: CacheKey, entry: CacheEntry) async

    /// Removes a cached entry for the given key
    func remove(_ key: CacheKey) async

    /// Removes all cached entries
    func removeAll() async

    /// Removes expired entries
    func removeExpired() async

    /// Removes cached entries by tags (for advanced storage implementations)
    func removeByTags(_ tags: [CacheTagName]) async

    /// Removes cached entries matching a pattern (for advanced storage implementations)
    func removeByPattern(_ pattern: CacheInvalidationPattern) async

    /// Removes specific keys (for advanced storage implementations)
    func removeByKeys(_ keys: [CacheKey]) async
  }

  /// Configuration for caching behavior
  public struct Configuration: Sendable {
    /// Default time-to-live for cached responses
    public let defaultTTL: CacheMaxAge

    /// Maximum size of the cache storage
    public let maxCacheSize: CacheEntryLimit?

    /// Predicate to determine if a request should be cached
    public let shouldCache: @Sendable (HTTPRequest, HTTPResponse) -> CacheDecision

    /// Function to generate cache keys from requests
    public let cacheKeyGenerator: @Sendable (HTTPRequest) -> CacheKey

    /// Function to generate cache keys with metadata support
    public let intelligentCacheKeyGenerator: @Sendable (HTTPRequest, CacheMetadata?) -> CacheKey

    /// Function to determine TTL for specific responses
    public let ttlCalculator: @Sendable (HTTPRequest, HTTPResponse) -> CacheMaxAge

    /// Function to extract cache metadata from request attributes
    public let metadataExtractor: @Sendable (HTTPRequest) -> CacheMetadata?

    /// Whether to use conditional requests (If-None-Match, If-Modified-Since)
    public let useConditionalRequests: CacheRevalidationFlag

    public init(
      defaultTTL: CacheMaxAge = 300.0,  // 5 minutes
      maxCacheSize: CacheEntryLimit? = 100,
      shouldCache: @escaping @Sendable (HTTPRequest, HTTPResponse) -> CacheDecision = Self
        .defaultShouldCache,
      cacheKeyGenerator: @escaping @Sendable (HTTPRequest) -> CacheKey = Self.defaultCacheKey,
      intelligentCacheKeyGenerator: @escaping @Sendable (HTTPRequest, CacheMetadata?) -> CacheKey =
        Self.defaultIntelligentCacheKey,
      ttlCalculator: (@Sendable (HTTPRequest, HTTPResponse) -> CacheMaxAge)? = nil,
      metadataExtractor: @escaping @Sendable (HTTPRequest) -> CacheMetadata? = Self
        .defaultMetadataExtractor,
      useConditionalRequests: CacheRevalidationFlag = true
    ) {
      self.defaultTTL = defaultTTL
      self.maxCacheSize = maxCacheSize
      self.shouldCache = shouldCache
      self.cacheKeyGenerator = cacheKeyGenerator
      self.intelligentCacheKeyGenerator = intelligentCacheKeyGenerator
      self.ttlCalculator =
        ttlCalculator ?? { _, response in
          Self.responseTTL(from: response) ?? defaultTTL
        }
      self.metadataExtractor = metadataExtractor
      self.useConditionalRequests = useConditionalRequests
    }

    /// Default predicate for determining if a response should be cached
    public static func defaultShouldCache(
      _ request: HTTPRequest,
      _ response: HTTPResponse
    ) -> CacheDecision {
      // Only cache GET requests
      guard request.method == .get else { return false }

      // Only cache successful responses
      guard response.status.isSuccess.rawValue else { return false }

      // Don't cache responses with Cache-Control: no-cache or no-store
      if let cacheControl = response.headers.caseInsensitiveValue(for: "Cache-Control")?
        .rawValue.lowercased()
      {
        if cacheControl.contains("no-cache") || cacheControl.contains("no-store") {
          return false
        }
      }

      return true
    }

    /// Default cache key generator
    public static func defaultCacheKey(_ request: HTTPRequest) -> CacheKey {
      CacheKey("\(request.method.rawValue.rawValue):\(request.url.absoluteString)")
    }

    /// Intelligent cache key generator that considers metadata
    public static func defaultIntelligentCacheKey(
      _ request: HTTPRequest,
      _ metadata: CacheMetadata?
    ) -> CacheKey {
      let authorizationPartition =
        request.headers
        .caseInsensitiveValue(for: "Authorization")
        .map { Data($0.rawValue.utf8).sha256 } ?? "public"

      if let customKey = metadata?.customKey {
        return CacheKey("\(customKey.rawValue):authorization:\(authorizationPartition)")
      }

      // Generate normalized URL key
      var components = URLComponents(url: request.url, resolvingAgainstBaseURL: false)

      // Sort query items for consistent caching
      if let queryItems = components?.queryItems {
        components?.queryItems = queryItems.sorted { $0.name < $1.name }
      }

      let normalizedURL = components?.url?.absoluteString ?? request.url.absoluteString

      let tagNames = metadata?.tags.sorted().map(\.rawValue) ?? []
      let encodedTags = tagNames.map { "\($0.utf8.count):\($0)" }.joined(separator: "|")
      let tagsPartition = encodedTags.isEmpty ? "none" : Data(encodedTags.utf8).sha256

      return CacheKey(
        "\(request.method.rawValue.rawValue):\(normalizedURL):authorization:\(authorizationPartition):tags:\(tagsPartition)"
      )
    }

    /// Default metadata extractor (placeholder for macro-generated code)
    public static func defaultMetadataExtractor(_ request: HTTPRequest) -> CacheMetadata? {
      // In a real implementation, this would extract metadata from method attributes
      // For now, return nil to use default behavior
      nil
    }

    /// Default TTL calculator that respects Cache-Control headers
    public static func defaultTTLCalculator(
      _ request: HTTPRequest,
      _ response: HTTPResponse
    ) -> CacheMaxAge {
      responseTTL(from: response) ?? 300.0  // 5 minutes
    }

    static func responseTTL(from response: HTTPResponse) -> CacheMaxAge? {
      cacheControlTTL(from: response) ?? expiresHeaderTTL(from: response)
    }

    private static func cacheControlTTL(from response: HTTPResponse) -> CacheMaxAge? {
      guard let cacheControl = response.headers.caseInsensitiveValue(for: "Cache-Control") else {
        return nil
      }

      let components = cacheControl.rawValue.lowercased().components(separatedBy: ",")
      for component in components {
        let trimmed = component.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("max-age=") else { continue }

        let maxAgeString = String(trimmed.dropFirst(8))
        guard let maxAge = TimeInterval(maxAgeString) else { continue }
        return CacheMaxAge(maxAge)
      }

      return nil
    }

    private static func expiresHeaderTTL(from response: HTTPResponse) -> CacheMaxAge? {
      guard let expires = response.headers.caseInsensitiveValue(for: "Expires") else {
        return nil
      }

      let formatter = DateFormatter()
      formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
      guard let expiresDate = formatter.date(from: expires.rawValue) else {
        return nil
      }

      let ttl = expiresDate.timeIntervalSinceNow
      return CacheMaxAge(max(ttl, 0))
    }
  }
}

public extension CachingMiddleware.CacheStorage {
  func getForRevalidation(_ key: CacheKey) async -> CachingMiddleware.CacheEntry? {
    await get(key)
  }
}

extension HTTPHeaders {
  func caseInsensitiveValue(for name: String) -> HTTPHeaderValue? {
    first { header in
      header.key.rawValue.caseInsensitiveCompare(name) == .orderedSame
    }?.value
  }
}
