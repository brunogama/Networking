import Foundation
import NetworkingCore

// swiftlint:disable file_length

// MARK: - Enhanced Memory Cache Storage

// swiftlint:disable type_body_length
/// Advanced in-memory cache storage with sophisticated eviction policies
public actor AdvancedMemoryCacheStorage: CachingMiddleware.CacheStorage {
  // MARK: - Cache Entry Wrapper

  /// Internal wrapper for cache entries with access metadata
  private struct MemoryCacheEntry: Sendable {
    let cacheEntry: CachingMiddleware.CacheEntry
    let accessCount: Int
    let lastAccessTime: Date
    let tags: Set<CacheTagName>
    let storageSize: StorageSizeBytes

    init(
      cacheEntry: CachingMiddleware.CacheEntry,
      accessCount: Int = 0,
      lastAccessTime: Date = Date(),
      tags: Set<CacheTagName> = [],
      storageSize: StorageSizeBytes
    ) {
      self.cacheEntry = cacheEntry
      self.accessCount = accessCount
      self.lastAccessTime = lastAccessTime
      self.tags = tags
      self.storageSize = storageSize
    }

    func incrementAccess() -> MemoryCacheEntry {
      MemoryCacheEntry(
        cacheEntry: cacheEntry,
        accessCount: accessCount + 1,
        lastAccessTime: Date(),
        tags: tags,
        storageSize: storageSize
      )
    }
  }

  // MARK: - Properties

  private var cache: [CacheKey: MemoryCacheEntry] = [:]
  private var tagIndex: [CacheTagName: Set<CacheKey>] = [:]  // tag -> cache keys
  private let policy: CachePolicy
  private let sizePolicy: CacheSizePolicy
  private let expirationStrategy: ExpirationStrategy
  private let queue = DispatchQueue(label: "AdvancedMemoryCacheStorage", qos: .utility)

  // MARK: - Metrics

  private var hitCount: Int64 = 0
  private var missCount: Int64 = 0
  private var evictionCount: Int64 = 0

  // MARK: - Initialization

  public init(
    policy: CachePolicy = .lru,
    sizePolicy: CacheSizePolicy = .maxEntries(1000),
    expirationStrategy: ExpirationStrategy = ExpirationStrategy()
  ) {
    self.policy = policy
    self.sizePolicy = sizePolicy
    self.expirationStrategy = expirationStrategy
  }

  // MARK: - CacheStorage Implementation

  public func keys() async -> [CacheKey] {
    Array(cache.keys)
  }

  public func get(_ key: CacheKey) async -> CachingMiddleware.CacheEntry? {
    if let wrapper = cache[key] {
      // Check expiration
      if wrapper.cacheEntry.isExpired.rawValue {
        await remove(key)
        missCount += 1
        return nil
      }

      // Update access metadata
      let updatedWrapper = wrapper.incrementAccess()
      cache[key] = updatedWrapper

      // Extend TTL if configured
      if expirationStrategy.extendOnAccess.rawValue {
        let extendedEntry = extendTTL(wrapper.cacheEntry)
        let finalWrapper = MemoryCacheEntry(
          cacheEntry: extendedEntry,
          accessCount: updatedWrapper.accessCount,
          lastAccessTime: updatedWrapper.lastAccessTime,
          tags: updatedWrapper.tags,
          storageSize: updatedWrapper.storageSize
        )
        cache[key] = finalWrapper
        hitCount += 1
        return extendedEntry
      }

      hitCount += 1
      return wrapper.cacheEntry
    }

    missCount += 1
    return nil
  }

  public func getForRevalidation(_ key: CacheKey) async -> CachingMiddleware.CacheEntry? {
    guard let entry = cache[key]?.cacheEntry else {
      missCount += 1
      return nil
    }

    hitCount += 1
    return entry
  }

  public func set(_ key: CacheKey, entry: CachingMiddleware.CacheEntry) async {
    await set(key, entry: entry, tags: [])
  }

  /// Enhanced set method with tag support
  public func set(_ key: CacheKey, entry: CachingMiddleware.CacheEntry, tags: [CacheTagName]) async
  {
    let tagSet = Set(tags)
    let wrapper = MemoryCacheEntry(
      cacheEntry: entry,
      tags: tagSet,
      storageSize: entry.response.cacheStorageSize
    )

    await remove(key)
    cache[key] = wrapper

    // Update tag index
    for tag in tagSet {
      if tagIndex[tag] == nil {
        tagIndex[tag] = Set<CacheKey>()
      }
      tagIndex[tag]?.insert(key)
    }

    await enforceSize()
  }

  public func remove(_ key: CacheKey) async {
    if let wrapper = cache.removeValue(forKey: key) {
      // Clean up tag index
      for tag in wrapper.tags {
        tagIndex[tag]?.remove(key)
        if tagIndex[tag]?.isEmpty == true {
          tagIndex.removeValue(forKey: tag)
        }
      }
    }
  }

  public func removeAll() async {
    cache.removeAll()
    tagIndex.removeAll()
  }

  public func removeExpired() async {
    let expiredKeys = cache.compactMap { key, wrapper in
      wrapper.cacheEntry.isExpired.rawValue ? key : nil
    }

    for key in expiredKeys {
      await remove(key)
    }
  }

  public func removeByTags(_ tags: [CacheTagName]) async {
    var keysToRemove = Set<CacheKey>()

    for tag in tags {
      if let taggedKeys = tagIndex[tag] {
        keysToRemove.formUnion(taggedKeys)
      }
    }

    for key in keysToRemove {
      await remove(key)
    }
  }

  public func removeByPattern(_ pattern: CacheInvalidationPattern) async {
    let regex: NSRegularExpression?
    do {
      let regexPattern =
        pattern.rawValue
        .replacingOccurrences(of: "*", with: ".*")
        .replacingOccurrences(of: "?", with: ".")
      regex = try NSRegularExpression(pattern: regexPattern, options: [])
    } catch {
      return
    }

    guard let regex = regex else { return }

    let keysToRemove = cache.keys.filter { key in
      let range = NSRange(location: 0, length: key.rawValue.utf16.count)
      return regex.firstMatch(in: key.rawValue, options: [], range: range) != nil
    }

    for key in keysToRemove {
      await remove(key)
    }
  }

  public func removeByKeys(_ keys: [CacheKey]) async {
    for key in keys {
      await remove(key)
    }
  }

  // MARK: - Size Management

  private func enforceSize() async {
    switch sizePolicy {
    case .maxEntries(let max):
      await enforceMaxEntries(max)

    case .maxMemory(let maxBytes):
      await enforceMaxMemory(maxBytes)

    case .maxDiskSize:
      // Not applicable for memory cache
      break

    case .combined(let entries, let memory):
      await enforceMaxEntries(entries)
      await enforceMaxMemory(memory)
    }
  }

  private func enforceMaxEntries(_ max: CacheEntryLimit) async {
    while cache.count > max.rawValue {
      guard let keyToEvict = await selectKeyForEviction() else { break }
      await remove(keyToEvict)
      evictionCount += 1
    }
  }

  private func enforceMaxMemory(_ maxBytes: StorageSizeBytes) async {
    while estimateMemoryUsage() > maxBytes {
      guard let keyToEvict = await selectKeyForEviction() else { break }
      await remove(keyToEvict)
      evictionCount += 1
    }
  }

  private func selectKeyForEviction() async -> CacheKey? {
    cache.min(by: evictionComparator())?.key
  }

  private func estimateMemoryUsage() -> StorageSizeBytes {
    cache.values.reduce(0) { $0 + $1.storageSize }
  }

  // MARK: - TTL Management

  private func extendTTL(_ entry: CachingMiddleware.CacheEntry) -> CachingMiddleware.CacheEntry {
    let currentAge = entry.age
    let originalTTL = entry.expiresAt.timeIntervalSince(entry.cachedAt)
    let extensionTime = originalTTL * expirationStrategy.extensionFactor.rawValue
    let newTTL = min(originalTTL + extensionTime, expirationStrategy.maxTTL.rawValue)

    return CachingMiddleware.CacheEntry(
      response: entry.response,
      ttl: CacheMaxAge(newTTL - currentAge.rawValue),
      etag: entry.etag,
      lastModified: entry.lastModified
    )
  }

  // MARK: - Metrics and Debugging

  /// Returns cache performance metrics
  public func getMetrics() async -> CacheMetrics {
    CacheMetrics(
      size: CacheEntryCount(cache.count),
      hitCount: CacheHitCount(hitCount),
      missCount: CacheMissCount(missCount),
      evictionCount: CacheEvictionCount(evictionCount),
      hitRatio: CacheHitRatioMetric(
        hitCount + missCount > 0 ? Double(hitCount) / Double(hitCount + missCount) : 0.0
      )
    )
  }

  /// Returns estimated memory usage in bytes
  public var estimatedMemoryUsage: StorageSizeBytes {
    get async { estimateMemoryUsage() }
  }
}
// swiftlint:enable type_body_length

private extension AdvancedMemoryCacheStorage {
  private typealias MemoryCacheComparator = (
    Dictionary<CacheKey, MemoryCacheEntry>.Element,
    Dictionary<
      CacheKey,
      MemoryCacheEntry
    >.Element
  ) -> Bool

  // swiftlint:disable:next cyclomatic_complexity
  private func evictionComparator() -> MemoryCacheComparator {
    switch policy {
    case .lru:
      return { lhs, rhs in
        lhs.value.lastAccessTime < rhs.value.lastAccessTime
      }

    case .lfu:
      return { lhs, rhs in
        lhs.value.accessCount < rhs.value.accessCount
      }

    case .fifo:
      return { lhs, rhs in
        lhs.value.cacheEntry.cachedAt < rhs.value.cacheEntry.cachedAt
      }

    case .ttlOnly:
      return { lhs, rhs in
        lhs.value.cacheEntry.expiresAt < rhs.value.cacheEntry.expiresAt
      }

    case .custom(let comparator):
      return { lhs, rhs in
        comparator(lhs.value.cacheEntry, rhs.value.cacheEntry).rawValue
      }
    }
  }
}
