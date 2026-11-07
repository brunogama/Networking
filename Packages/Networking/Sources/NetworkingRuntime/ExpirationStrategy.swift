import NetworkingCore

/// Cache expiration strategies.
public struct ExpirationStrategy: Sendable {
  /// Default TTL for entries without explicit expiration.
  public let defaultTTL: CacheMaxAge

  /// Maximum TTL allowed (caps explicit TTLs).
  public let maxTTL: CacheMaxAge

  /// Minimum TTL allowed (floors explicit TTLs).
  public let minTTL: CacheMaxAge

  /// Whether to extend TTL on cache hits.
  public let extendOnAccess: CacheExtensionOnAccessFlag

  /// Factor to extend TTL by when extending on access (0.0-1.0).
  public let extensionFactor: CacheExtensionFactor

  /// Configures freshness bounds and optional extension on access.
  public init(
    defaultTTL: CacheMaxAge = 300.0,
    maxTTL: CacheMaxAge = 3600.0,
    minTTL: CacheMaxAge = 60.0,
    extendOnAccess: CacheExtensionOnAccessFlag = false,
    extensionFactor: CacheExtensionFactor = 0.5
  ) {
    self.defaultTTL = defaultTTL
    self.maxTTL = maxTTL
    self.minTTL = minTTL
    self.extendOnAccess = extendOnAccess
    self.extensionFactor = CacheExtensionFactor(max(0.0, min(1.0, extensionFactor.rawValue)))
  }
}
