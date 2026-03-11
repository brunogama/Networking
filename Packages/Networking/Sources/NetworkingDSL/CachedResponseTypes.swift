import Foundation
import NetworkingCore

// MARK: - Cached Response Types

/// A response that includes comprehensive cache metadata and hit information
public struct CachedResponse<T: Sendable>: ValidatedResponseProtocol, Sendable {
  public typealias ValueType = T

  public let response: HTTPResponse
  public let value: T
  public let validationResults: [ValidationResult]
  public let cacheMetadata: CacheMetadata
  public let isCacheHit: CacheHitFlag
  public let cacheTimestamp: Date

  public init(
    response: HTTPResponse,
    value: T,
    cacheMetadata: CacheMetadata,
    isCacheHit: CacheHitFlag = false,
    cacheTimestamp: Date = Date(),
    validationResults: [ValidationResult] = [.success]
  ) {
    self.response = response
    self.value = value
    self.cacheMetadata = cacheMetadata
    self.isCacheHit = isCacheHit
    self.cacheTimestamp = cacheTimestamp
    self.validationResults = validationResults
  }

  /// Cache age since the response was first cached
  public var cacheAge: NetworkingCore.RequestTimeout {
    NetworkingCore.RequestTimeout(Date().timeIntervalSince(cacheTimestamp))
  }

  /// Whether the cached response is still fresh (within TTL)
  public var isFresh: CacheFreshnessFlag {
    guard let ttl = cacheMetadata.ttl else { return CacheFreshnessFlag(true) }
    return CacheFreshnessFlag(cacheAge < ttl)
  }

  /// Whether the response needs revalidation
  public var needsRevalidation: CacheRevalidationRequiredFlag {
    CacheRevalidationRequiredFlag(!isFresh.rawValue || cacheMetadata.tags.isEmpty)
  }
}
