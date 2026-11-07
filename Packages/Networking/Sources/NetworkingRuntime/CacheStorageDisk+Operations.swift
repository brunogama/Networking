import Foundation
import NetworkingCore

extension DiskCacheStorage {
  /// Lists indexed keys, including stale entries retained for revalidation.
  public func keys() async -> [CacheKey] {
    loadMetadataIfNeeded()
    return Array(metadata.keys)
  }

  /// Returns a fresh entry, discarding expired or corrupt data.
  public func get(_ key: CacheKey) async -> CachingMiddleware.CacheEntry? {
    loadMetadataIfNeeded()
    guard let metadata = metadata[key] else { return nil }
    guard Date() < metadata.expiresAt else {
      deleteEntries([key])
      return nil
    }
    return loadEntry(key, metadata: metadata)
  }

  /// Returns retained content and validators even after freshness expires.
  public func getForRevalidation(_ key: CacheKey) async -> CachingMiddleware.CacheEntry? {
    loadMetadataIfNeeded()
    guard let metadata = metadata[key] else { return nil }
    return loadEntry(key, metadata: metadata)
  }

  /// Stores response content and the entry's invalidation tags.
  public func set(_ key: CacheKey, entry: CachingMiddleware.CacheEntry) async {
    store(key, entry: entry, tags: entry.tags)
  }

  /// Stores response content with explicitly supplied invalidation tags.
  public func set(_ key: CacheKey, entry: CachingMiddleware.CacheEntry, tags: [CacheTagName]) async
  {
    store(key, entry: entry, tags: tags)
  }

  /// Removes one indexed entry.
  public func remove(_ key: CacheKey) async {
    loadMetadataIfNeeded()
    deleteEntries([key])
  }

  /// Clears cache-owned files, preserving other files and directories in the supplied directory.
  public func removeAll() async {
    for file in ownedDataFiles() { try? fileManager.removeItem(at: file) }
    metadata.removeAll()
    tagIndex.removeAll()
    metadataLoaded = true
    saveMetadata()
  }

  /// Removes expired entries with one metadata write.
  public func removeExpired() async {
    loadMetadataIfNeeded()
    let now = Date()
    deleteEntries(metadata.compactMap { now >= $0.value.expiresAt ? $0.key : nil })
  }

  /// Removes entries matching any supplied tag with one metadata write.
  public func removeByTags(_ tags: [CacheTagName]) async {
    loadMetadataIfNeeded()
    let keys = Set(tags).reduce(into: Set<CacheKey>()) {
      $0.formUnion(tagIndex[$1] ?? [])
    }
    deleteEntries(Array(keys))
  }

  /// Removes whole keys matching `*` and `?`; all other characters are literal.
  public func removeByPattern(_ pattern: CacheInvalidationPattern) async {
    loadMetadataIfNeeded()
    let regex = cachePatternRegex(pattern)
    let keys = metadata.keys.filter { key in
      let range = NSRange(location: 0, length: key.rawValue.utf16.count)
      return regex?.firstMatch(in: key.rawValue, range: range) != nil
    }
    deleteEntries(keys)
  }

  /// Removes the supplied keys with one metadata write.
  public func removeByKeys(_ keys: [CacheKey]) async {
    loadMetadataIfNeeded()
    deleteEntries(keys)
  }

  /// Bytes retained in indexed response files.
  public var diskUsage: StorageSizeBytes {
    get async {
      loadMetadataIfNeeded()
      return currentDiskUsage
    }
  }

  /// Directory containing cache-owned files.
  public var cacheDirectoryURL: CacheDirectoryURL { cacheDirectory }
}
