import NetworkingCore

/// Storage for response entries; implementations own their internal synchronization.
public protocol HTTPResponseCacheStorage: Sendable {
  /// Lists retained keys.
  func keys() async -> [CacheKey]
  /// Looks up a fresh entry and records storage access.
  func get(_ key: CacheKey) async -> CachingMiddleware.CacheEntry?
  /// Looks up validators without discarding expired content.
  func getForRevalidation(_ key: CacheKey) async -> CachingMiddleware.CacheEntry?
  /// Stores an entry and its tags atomically.
  func set(_ key: CacheKey, entry: CachingMiddleware.CacheEntry) async
  /// Removes one entry.
  func remove(_ key: CacheKey) async
  /// Removes every entry.
  func removeAll() async
  /// Removes expired entries.
  func removeExpired() async
  /// Removes entries associated with any supplied tag.
  func removeByTags(_ tags: [CacheTagName]) async
  /// Removes entries selected by the storage's pattern syntax.
  func removeByPattern(_ pattern: CacheInvalidationPattern) async
  /// Removes selected keys.
  func removeByKeys(_ keys: [CacheKey]) async
}
