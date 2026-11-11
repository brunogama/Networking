import Foundation
import NetworkingCore

/// A basic in-memory cache storage implementation.
public actor MemoryCacheStorage: HTTPResponseCacheStorage {
  private var cache: [CacheKey: CachingMiddleware.CacheEntry] = [:]
  private let maxSize: CacheEntryLimit?

  public init(maxSize: CacheEntryLimit? = CacheEntryLimit(rawValue: 100)) {
    self.maxSize = maxSize
  }

  public func keys() async -> [CacheKey] {
    Array(cache.keys)
  }

  public func get(_ key: CacheKey) async -> CachingMiddleware.CacheEntry? {
    guard let entry = cache[key] else {
      return nil
    }

    if entry.isExpired.rawValue {
      cache.removeValue(forKey: key)
      return nil
    }

    return entry
  }

  public func getForRevalidation(_ key: CacheKey) async -> CachingMiddleware.CacheEntry? {
    cache[key]
  }

  public func set(_ key: CacheKey, entry: CachingMiddleware.CacheEntry) async {
    await removeExpired()

    if let maxSize, maxSize.rawValue <= 0 { return }
    if cache[key] == nil, let maxSize, cache.count >= maxSize.rawValue {
      let oldestKey = cache.min { lhs, rhs in
        lhs.value.cachedAt < rhs.value.cachedAt
      }?.key

      if let keyToRemove = oldestKey {
        cache.removeValue(forKey: keyToRemove)
      }
    }

    cache[key] = entry
  }

  public func remove(_ key: CacheKey) async {
    cache.removeValue(forKey: key)
  }

  public func removeAll() async {
    cache.removeAll()
  }

  public func removeExpired() async {
    let now = Date()
    cache = cache.filter { _, entry in
      now <= entry.expiresAt
    }
  }

  public func removeByTags(_ tags: [CacheTagName]) async {
    let requested = Set(tags)
    cache = cache.filter { requested.isDisjoint(with: $0.value.tags) }
  }

  public func removeByPattern(_ pattern: CacheInvalidationPattern) async {
    let regex = cachePatternRegex(pattern)

    let keysToRemove = cache.keys.filter { key in
      let range = NSRange(location: 0, length: key.rawValue.utf16.count)
      return regex?.firstMatch(in: key.rawValue, options: [], range: range) != nil
    }

    for key in keysToRemove {
      cache.removeValue(forKey: key)
    }
  }

  public func removeByKeys(_ keys: [CacheKey]) async {
    for key in keys {
      cache.removeValue(forKey: key)
    }
  }

  public var size: CacheEntryCount {
    get async { CacheEntryCount(cache.count) }
  }
}
