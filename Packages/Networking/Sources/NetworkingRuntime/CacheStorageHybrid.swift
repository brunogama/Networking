import Foundation
import NetworkingCore

// MARK: - Hybrid Cache Storage

/// Combines memory and disk caching for optimal performance
public actor HybridCacheStorage: CachingMiddleware.CacheStorage {
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
    let memoryKeys = await memoryCache.keys()
    let diskKeys = await diskCache.keys()
    return Array(Set(memoryKeys).union(diskKeys))
  }

  public func get(_ key: CacheKey) async -> CachingMiddleware.CacheEntry? {
    // Try memory first
    if let entry = await memoryCache.get(key) {
      return entry
    }

    // Try disk
    if let entry = await diskCache.get(key) {
      // Promote to memory if small enough
      let responseSize = entry.response.cacheStorageSize
      if responseSize <= memoryThreshold {
        await memoryCache.set(key, entry: entry)
      }
      return entry
    }

    return nil
  }

  public func getForRevalidation(_ key: CacheKey) async -> CachingMiddleware.CacheEntry? {
    if let entry = await memoryCache.getForRevalidation(key) {
      return entry
    }

    return await diskCache.getForRevalidation(key)
  }

  public func set(_ key: CacheKey, entry: CachingMiddleware.CacheEntry) async {
    let responseSize = entry.response.cacheStorageSize

    if responseSize <= memoryThreshold {
      await memoryCache.set(key, entry: entry)
    } else {
      await memoryCache.remove(key)
    }

    // Disk is the durable backing store; memory is the fast front cache.
    await diskCache.set(key, entry: entry)
  }

  public func remove(_ key: CacheKey) async {
    await memoryCache.remove(key)
    await diskCache.remove(key)
  }

  public func removeAll() async {
    await memoryCache.removeAll()
    await diskCache.removeAll()
  }

  public func removeExpired() async {
    await memoryCache.removeExpired()
    await diskCache.removeExpired()
  }

  public func removeByTags(_ tags: [CacheTagName]) async {
    await memoryCache.removeByTags(tags)
    await diskCache.removeByTags(tags)
  }

  public func removeByPattern(_ pattern: CacheInvalidationPattern) async {
    await memoryCache.removeByPattern(pattern)
    await diskCache.removeByPattern(pattern)
  }

  public func removeByKeys(_ keys: [CacheKey]) async {
    await memoryCache.removeByKeys(keys)
    await diskCache.removeByKeys(keys)
  }

  /// Returns combined cache metrics
  public func getMetrics() async -> (memory: CacheMetrics, disk: StorageSizeBytes) {
    let memoryMetrics = await memoryCache.getMetrics()
    let diskUsage = await diskCache.diskUsage
    return (memory: memoryMetrics, disk: diskUsage)
  }
}
