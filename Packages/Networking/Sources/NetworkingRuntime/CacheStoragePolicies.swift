import Foundation
import NetworkingCore

// swiftlint:disable file_length

// MARK: - Cache Policy and Expiration Strategies

/// Cache policy definitions for different storage strategies
public enum CachePolicy: Sendable {
  /// Least Recently Used eviction
  case lru
  /// Least Frequently Used eviction
  case lfu
  /// First In, First Out eviction
  case fifo
  /// Time-to-live based eviction only
  case ttlOnly
  /// Custom eviction strategy
  case custom(
    @Sendable (CachingMiddleware.CacheEntry, CachingMiddleware.CacheEntry) -> CacheEvictionDecision
  )
}

/// Cache size management strategies
public enum CacheSizePolicy: Sendable {
  /// Maximum number of entries
  case maxEntries(CacheEntryLimit)
  /// Maximum memory usage in bytes
  case maxMemory(StorageSizeBytes)
  /// Maximum disk usage in bytes
  case maxDiskSize(StorageSizeBytes)
  /// Combined entry and memory limits
  case combined(entries: CacheEntryLimit, memory: StorageSizeBytes)
}

/// Cache expiration strategies
public struct ExpirationStrategy: Sendable {
  /// Default TTL for entries without explicit expiration
  public let defaultTTL: CacheMaxAge

  /// Maximum TTL allowed (caps explicit TTLs)
  public let maxTTL: CacheMaxAge

  /// Minimum TTL allowed (floors explicit TTLs)
  public let minTTL: CacheMaxAge

  /// Whether to extend TTL on cache hits
  public let extendOnAccess: CacheExtensionOnAccessFlag

  /// Factor to extend TTL by when extending on access (0.0-1.0)
  public let extensionFactor: CacheExtensionFactor

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
