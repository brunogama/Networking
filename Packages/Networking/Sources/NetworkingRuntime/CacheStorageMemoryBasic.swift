import Foundation
import NetworkingCore

/// A basic in-memory cache storage implementation.
public actor MemoryCacheStorage: CachingMiddleware.CacheStorage {
  private var cache: [CacheKey: CachingMiddleware.CacheEntry] = [:]
  private let maxSize: CacheEntryLimit?

  /// Creates a new memory cache storage.
  /// - Parameter maxSize: Maximum number of entries to store.
  public init(maxSize: CacheEntryLimit? = CacheEntryLimit(rawValue: 100)) {
    self.maxSize = maxSize
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

  public func set(_ key: CacheKey, entry: CachingMiddleware.CacheEntry) async {
    await removeExpired()

    if let maxSize = maxSize, cache.count >= maxSize.rawValue {
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
    _ = tags
    // Basic memory cache does not retain tag metadata.
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
      cache.removeValue(forKey: key)
    }
  }

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
