import NetworkingCore

extension CachingMiddleware {

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
