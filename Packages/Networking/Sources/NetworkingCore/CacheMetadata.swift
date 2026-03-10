import Foundation

/// Cache configuration metadata extracted from method attributes.
public struct CacheMetadata: Sendable {
  public let ttl: RequestTimeout?
  public let tags: [CacheTagName]
  public let customKey: CacheKey?
  public let isInvalidating: CacheInvalidationFlag
  public let invalidationTags: [CacheTagName]
  public let invalidationPattern: CacheInvalidationPattern?
  public let invalidationKeys: [CacheKey]

  public init(
    ttl: RequestTimeout? = nil,
    tags: [CacheTagName] = [],
    customKey: CacheKey? = nil,
    isInvalidating: CacheInvalidationFlag = CacheInvalidationFlag(rawValue: false),
    invalidationTags: [CacheTagName] = [],
    invalidationPattern: CacheInvalidationPattern? = nil,
    invalidationKeys: [CacheKey] = []
  ) {
    self.ttl = ttl
    self.tags = tags
    self.customKey = customKey
    self.isInvalidating = isInvalidating
    self.invalidationTags = invalidationTags
    self.invalidationPattern = invalidationPattern
    self.invalidationKeys = invalidationKeys
  }
}
