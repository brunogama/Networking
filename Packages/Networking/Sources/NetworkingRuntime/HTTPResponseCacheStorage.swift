import NetworkingCore

/// Storage for response entries; implementations own their internal synchronization.
public protocol HTTPResponseCacheStorage: Sendable {

  func keys() async -> [CacheKey]

  func get(_ key: CacheKey) async -> CachingMiddleware.CacheEntry?

  func getForRevalidation(_ key: CacheKey) async -> CachingMiddleware.CacheEntry?

  func set(_ key: CacheKey, entry: CachingMiddleware.CacheEntry) async

  func remove(_ key: CacheKey) async

  func removeAll() async

  func removeExpired() async

  func removeByTags(_ tags: [CacheTagName]) async

  func removeByPattern(_ pattern: CacheInvalidationPattern) async

  func removeByKeys(_ keys: [CacheKey]) async
}
