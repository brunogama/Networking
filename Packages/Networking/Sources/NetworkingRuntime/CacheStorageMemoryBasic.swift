import Foundation
import NetworkingCore

/// A basic in-memory cache storage implementation.
public actor MemoryCacheStorage: HTTPResponseCacheStorage {
  private var cache: [CacheKey: CachingMiddleware.CacheEntry] = [:]
  private let maxSize: CacheEntryLimit?

  /// Creates a new memory cache storage.
  /// - Parameter maxSize: Maximum number of entries to store.
  public init(maxSize: CacheEntryLimit? = CacheEntryLimit(rawValue: 100)) {
    self.maxSize = maxSize
  }

  /// Lists retained keys.
  public func keys() async -> [CacheKey] {
    Array(cache.keys)
  }

  /// Returns a fresh entry.
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

  /// Returns an entry including stale validators.
  public func getForRevalidation(_ key: CacheKey) async -> CachingMiddleware.CacheEntry? {
    cache[key]
  }

  /// Stores an entry and its tags, respecting capacity.
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

  /// Removes one key.
  public func remove(_ key: CacheKey) async {
    cache.removeValue(forKey: key)
  }

  /// Clears all entries.
  public func removeAll() async {
    cache.removeAll()
  }

  /// Removes stale entries.
  public func removeExpired() async {
    let now = Date()
    cache = cache.filter { _, entry in
      now <= entry.expiresAt
    }
  }

  /// Removes entries matching any supplied tag.
  public func removeByTags(_ tags: [CacheTagName]) async {
    let requested = Set(tags)
    cache = cache.filter { requested.isDisjoint(with: $0.value.tags) }
  }

  /// Removes whole keys matching a wildcard pattern.
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

  /// Removes the supplied keys.
  public func removeByKeys(_ keys: [CacheKey]) async {
    for key in keys {
      cache.removeValue(forKey: key)
    }
  }

  /// Returns the current cache size.
  public var size: CacheEntryCount {
    get async { CacheEntryCount(cache.count) }
  }
}
