import Foundation
import NetworkingCore

// swiftlint:disable file_length

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

  public func get(_ key: CacheKey) async -> CachingMiddleware.CacheEntry? {
    // Try memory first
    if let entry = await memoryCache.get(key) {
      return entry
    }

    // Try disk
    if let entry = await diskCache.get(key) {
      // Promote to memory if small enough
      let responseSize = estimateResponseSize(entry.response)
      if responseSize <= memoryThreshold {
        await memoryCache.set(key, entry: entry)
      }
      return entry
    }

    return nil
  }

  public func set(_ key: CacheKey, entry: CachingMiddleware.CacheEntry) async {
    let responseSize = estimateResponseSize(entry.response)

    if responseSize <= memoryThreshold {
      // Small enough for memory
      await memoryCache.set(key, entry: entry)
    } else {
      // Too large, store on disk
      await diskCache.set(key, entry: entry)
    }
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

  private func estimateResponseSize(_ response: HTTPResponse) -> StorageSizeBytes {
    var size: StorageSizeBytes = 0

    // Headers
    for (key, value) in response.headers {
      // swiftlint:disable:next shorthand_operator
      size = size + StorageSizeBytes(Int64(key.utf8.count + value.utf8.count))
    }

    // Body
    if let body = response.body {
      // swiftlint:disable:next shorthand_operator
      size = size + StorageSizeBytes(Int64(body.count.rawValue))
    }

    return size
  }

  /// Returns combined cache metrics
  public func getMetrics() async -> (memory: CacheMetrics, disk: StorageSizeBytes) {
    let memoryMetrics = await memoryCache.getMetrics()
    let diskUsage = await diskCache.diskUsage
    return (memory: memoryMetrics, disk: diskUsage)
  }
}
