import NetworkingCore

extension CachingMiddleware {
  /// Creates a caching middleware with default memory storage.
  /// - Parameters:
  ///   - client: The HTTP client to use.
  ///   - ttl: Default time-to-live for cached responses.
  ///   - maxCacheSize: Maximum number of entries in the cache.
  /// - Returns: A configured caching middleware.
  public static func withMemoryStorage(
    client: any HTTPClient,
    ttl: CacheMaxAge = 300.0,
    maxCacheSize: CacheEntryLimit = 100
  ) -> CachingMiddleware {
    let storage = MemoryCacheStorage(maxSize: maxCacheSize)
    let configuration = Configuration(
      defaultTTL: ttl,
      maxCacheSize: maxCacheSize
    )

    return CachingMiddleware(
      configuration: configuration,
      storage: storage,
      client: client
    )
  }

  /// Creates a caching middleware with custom configuration.
  /// - Parameters:
  ///   - client: The HTTP client to use.
  ///   - customConfiguration: Custom configuration closure.
  /// - Returns: A configured caching middleware.
  public static func withCustomConfiguration(
    client: any HTTPClient,
    customConfiguration: (inout Configuration) -> Void
  ) -> CachingMiddleware {
    var config = Configuration()
    customConfiguration(&config)

    let storage = MemoryCacheStorage(maxSize: config.maxCacheSize)

    return CachingMiddleware(
      configuration: config,
      storage: storage,
      client: client
    )
  }
}
