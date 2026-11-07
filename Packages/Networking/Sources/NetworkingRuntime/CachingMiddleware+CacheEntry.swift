import Foundation
import NetworkingCore

extension CachingMiddleware {
  /// A response retained with freshness validators and invalidation tags.
  public struct CacheEntry: Sendable {

    public let response: HTTPResponse

    public let cachedAt: Date

    public let expiresAt: Date

    public let etag: HTTPHeaderValue?

    public let lastModified: HTTPHeaderValue?

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

    public var isExpired: CacheExpirationFlag { CacheExpirationFlag(Date() >= expiresAt) }

    public var age: CacheEntryAge { CacheEntryAge(Date().timeIntervalSince(cachedAt)) }
  }
}
