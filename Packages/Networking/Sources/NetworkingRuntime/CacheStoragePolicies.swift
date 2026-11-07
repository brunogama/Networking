import NetworkingCore

// MARK: - Cache Policy and Expiration Strategies

/// Cache policy definitions for different storage strategies.
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
