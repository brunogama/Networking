import NetworkingCore

// MARK: - Cache Policy and Expiration Strategies

/// Cache policy definitions for different storage strategies.
public enum CachePolicy: Sendable {

  case lru

  case lfu

  case fifo

  case ttlOnly

  case custom(
    @Sendable (CachingMiddleware.CacheEntry, CachingMiddleware.CacheEntry) -> CacheEvictionDecision
  )
}
