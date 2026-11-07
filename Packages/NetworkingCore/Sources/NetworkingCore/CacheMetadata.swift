/// Per-request storage and invalidation policy supplied to caching middleware.
public struct CacheMetadata: Sendable {
  /// Optional freshness duration for the cached response, in seconds.
  public let ttl: RequestTimeout?
  /// Tags attached to the stored response for later invalidation.
  public let tags: [CacheTagName]
  /// Optional caller-selected key used by the configured cache-key policy.
  public let customKey: CacheKey?
  /// Whether this request invalidates selected entries before execution.
  public let isInvalidating: CacheInvalidationFlag
  /// Tags identifying responses to invalidate.
  public let invalidationTags: [CacheTagName]
  /// Optional pattern selecting cache keys to invalidate.
  public let invalidationPattern: CacheInvalidationPattern?
  /// Explicit cache keys to invalidate.
  public let invalidationKeys: [CacheKey]

  /// Captures explicit storage and invalidation settings for one request.
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
