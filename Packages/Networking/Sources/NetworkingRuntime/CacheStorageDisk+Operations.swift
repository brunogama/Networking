import Foundation
import NetworkingCore

extension DiskCacheStorage {

  public func keys() async -> [CacheKey] {
    loadMetadataIfNeeded()
    return Array(metadata.keys)
  }

  public func get(_ key: CacheKey) async -> CachingMiddleware.CacheEntry? {
    loadMetadataIfNeeded()
    guard let metadata = metadata[key] else { return nil }
    guard Date() < metadata.expiresAt else {
      deleteEntries([key])
      return nil
    }
    return loadEntry(key, metadata: metadata)
  }

  public func getForRevalidation(_ key: CacheKey) async -> CachingMiddleware.CacheEntry? {
    loadMetadataIfNeeded()
    guard let metadata = metadata[key] else { return nil }
    return loadEntry(key, metadata: metadata)
  }

  public func set(_ key: CacheKey, entry: CachingMiddleware.CacheEntry) async {
    store(key, entry: entry, tags: entry.tags)
  }

  public func set(_ key: CacheKey, entry: CachingMiddleware.CacheEntry, tags: [CacheTagName]) async
  {
    store(key, entry: entry, tags: tags)
  }

  public func remove(_ key: CacheKey) async {
    loadMetadataIfNeeded()
    deleteEntries([key])
  }

  public func removeAll() async {
    for file in ownedDataFiles() { try? fileManager.removeItem(at: file) }
    metadata.removeAll()
    tagIndex.removeAll()
    metadataLoaded = true
    saveMetadata()
  }

  public func removeExpired() async {
    loadMetadataIfNeeded()
    let now = Date()
    deleteEntries(metadata.compactMap { now >= $0.value.expiresAt ? $0.key : nil })
  }

  public func removeByTags(_ tags: [CacheTagName]) async {
    loadMetadataIfNeeded()
    let keys = Set(tags).reduce(into: Set<CacheKey>()) {
      $0.formUnion(tagIndex[$1] ?? [])
    }
    deleteEntries(Array(keys))
  }

  public func removeByPattern(_ pattern: CacheInvalidationPattern) async {
    loadMetadataIfNeeded()
    let regex = cachePatternRegex(pattern)
    let keys = metadata.keys.filter { key in
      let range = NSRange(location: 0, length: key.rawValue.utf16.count)
      return regex?.firstMatch(in: key.rawValue, range: range) != nil
    }
    deleteEntries(keys)
  }

  public func removeByKeys(_ keys: [CacheKey]) async {
    loadMetadataIfNeeded()
    deleteEntries(keys)
  }

  public var diskUsage: StorageSizeBytes {
    get async {
      loadMetadataIfNeeded()
      return currentDiskUsage
    }
  }

  public var cacheDirectoryURL: CacheDirectoryURL { cacheDirectory }
}
