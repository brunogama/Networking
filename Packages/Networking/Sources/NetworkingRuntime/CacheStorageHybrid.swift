import NetworkingCore

// MARK: - Hybrid Cache Storage

/// Combines memory and disk caching for optimal performance
public actor HybridCacheStorage: HTTPResponseCacheStorage {
  private let operations = CacheMutationGate()
  private let memoryCache: AdvancedMemoryCacheStorage
  private let diskCache: DiskCacheStorage
  private let memoryThreshold: StorageSizeBytes  // Entries larger than this go directly to disk

  public init(
    memorySizePolicy: CacheSizePolicy = .maxEntries(500),
    diskSizePolicy: CacheSizePolicy = .maxDiskSize(52_428_800),
    memoryThreshold: StorageSizeBytes = 10_240,  // 10KB
    cacheDirectory: CacheDirectoryURL? = nil
  ) throws {
    self.memoryCache = AdvancedMemoryCacheStorage(
      policy: .lru,
      sizePolicy: memorySizePolicy
    )
    self.diskCache = try DiskCacheStorage(
      cacheDirectory: cacheDirectory,
      sizePolicy: diskSizePolicy
    )
    self.memoryThreshold = memoryThreshold
  }

  public func keys() async -> [CacheKey] {
    await operations.acquire()
    let memoryKeys = await memoryCache.keys()
    let diskKeys = await diskCache.keys()
    await operations.release()
    return Array(Set(memoryKeys).union(diskKeys))
  }

  public func get(_ key: CacheKey) async -> CachingMiddleware.CacheEntry? {
    await operations.acquire()
    let result = await lookup(key)
    await operations.release()
    return result
  }

  private func lookup(_ key: CacheKey) async -> CachingMiddleware.CacheEntry? {
    if let entry = await memoryCache.get(key) {
      return entry
    }

    if let entry = await diskCache.get(key) {
      let responseSize = entry.response.cacheStorageSize
      if responseSize <= memoryThreshold {
        await memoryCache.set(key, entry: entry)
      }
      return entry
    }

    return nil
  }

  public func getForRevalidation(_ key: CacheKey) async -> CachingMiddleware.CacheEntry? {
    await operations.acquire()
    var result = await memoryCache.getForRevalidation(key)
    if result == nil { result = await diskCache.getForRevalidation(key) }
    await operations.release()
    return result
  }

  public func set(_ key: CacheKey, entry: CachingMiddleware.CacheEntry) async {
    await operations.acquire()
    let responseSize = entry.response.cacheStorageSize

    if responseSize <= memoryThreshold {
      await memoryCache.set(key, entry: entry)
    } else {
      await memoryCache.remove(key)
    }

    await diskCache.set(key, entry: entry)
    await operations.release()
  }

  public func remove(_ key: CacheKey) async {
    await operations.acquire()
    await memoryCache.remove(key)
    await diskCache.remove(key)
    await operations.release()
  }

  public func removeAll() async {
    await operations.acquire()
    await memoryCache.removeAll()
    await diskCache.removeAll()
    await operations.release()
  }

  public func removeExpired() async {
    await operations.acquire()
    await memoryCache.removeExpired()
    await diskCache.removeExpired()
    await operations.release()
  }

  public func removeByTags(_ tags: [CacheTagName]) async {
    await operations.acquire()
    await memoryCache.removeByTags(tags)
    await diskCache.removeByTags(tags)
    await operations.release()
  }

  public func removeByPattern(_ pattern: CacheInvalidationPattern) async {
    await operations.acquire()
    await memoryCache.removeByPattern(pattern)
    await diskCache.removeByPattern(pattern)
    await operations.release()
  }

  public func removeByKeys(_ keys: [CacheKey]) async {
    await operations.acquire()
    await memoryCache.removeByKeys(keys)
    await diskCache.removeByKeys(keys)
    await operations.release()
  }

  public func getMetrics() async -> (memory: CacheMetrics, disk: StorageSizeBytes) {
    await operations.acquire()
    let memoryMetrics = await memoryCache.getMetrics()
    let diskUsage = await diskCache.diskUsage
    await operations.release()
    return (memory: memoryMetrics, disk: diskUsage)
  }
}
