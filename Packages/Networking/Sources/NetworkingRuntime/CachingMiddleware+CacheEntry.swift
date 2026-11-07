import Foundation
import NetworkingCore

extension CachingMiddleware {
  /// A response retained with freshness validators and invalidation tags.
  public struct CacheEntry: Sendable {
    /// Retained response representation.
    public let response: HTTPResponse
    /// Storage time.
    public let cachedAt: Date
    /// Freshness expiration time.
    public let expiresAt: Date
    /// Entity validator for conditional requests.
    public let etag: HTTPHeaderValue?
    /// Modification-date validator for conditional requests.
    public let lastModified: HTTPHeaderValue?
    /// Invalidation tags supplied when the entry was cached.
    public internal(set) var tags: [CacheTagName] = []

    init(
      response: HTTPResponse,
      ttl: CacheMaxAge,
      etag: HTTPHeaderValue? = nil,
      lastModified: HTTPHeaderValue? = nil
    ) {
      self.response = response
      self.cachedAt = Date()
      self.expiresAt = cachedAt.addingTimeInterval(ttl.rawValue)
      self.etag = etag
      self.lastModified = lastModified
    }

    /// Whether the entry is no longer fresh.
    public var isExpired: CacheExpirationFlag { CacheExpirationFlag(Date() >= expiresAt) }
    /// Time elapsed since storage.
    public var age: CacheEntryAge { CacheEntryAge(Date().timeIntervalSince(cachedAt)) }
  }
}
