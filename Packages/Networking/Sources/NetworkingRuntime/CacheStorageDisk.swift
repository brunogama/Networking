import Foundation
import NetworkingCore

// swiftlint:disable file_length

// MARK: - Disk Cache Storage

// swiftlint:disable type_body_length
/// Persistent disk-based cache storage with compression and integrity checks
public actor DiskCacheStorage: CachingMiddleware.CacheStorage {
  // MARK: - Disk Cache Entry

  private struct DiskCacheMetadata: Codable, Sendable {
    let key: CacheKey
    let cachedAt: Date
    let expiresAt: Date
    let etag: HTTPHeaderValue?
    let lastModified: HTTPHeaderValue?
    let tags: [CacheTagName]
    let dataSize: StorageSizeBytes
    let checksum: FileChecksum
  }

  // MARK: - Properties

  private let cacheDirectory: CacheDirectoryURL
  private let metadataFile: CacheDirectoryURL
  private var metadata: [CacheKey: DiskCacheMetadata] = [:]
  private var tagIndex: [CacheTagName: Set<CacheKey>] = [:]
  private let sizePolicy: CacheSizePolicy
  private let expirationStrategy: ExpirationStrategy
  private let compressionEnabled: CompressionEnabledFlag
  private let fileManager = FileManager.default

  // MARK: - Initialization

  public init(
    cacheDirectory: CacheDirectoryURL? = nil,
    sizePolicy: CacheSizePolicy = .maxDiskSize(104_857_600),  // 100MB
    expirationStrategy: ExpirationStrategy = ExpirationStrategy(),
    compressionEnabled: CompressionEnabledFlag = true
  ) throws {
    self.sizePolicy = sizePolicy
    self.expirationStrategy = expirationStrategy
    self.compressionEnabled = compressionEnabled

    // Setup cache directory
    if let cacheDirectory = cacheDirectory {
      self.cacheDirectory = cacheDirectory
    } else {
      let appSupport = try fileManager.url(
        for: .cachesDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
      )
      self.cacheDirectory = CacheDirectoryURL(appSupport.appendingPathComponent("NetworkingCache"))
    }

    self.metadataFile = self.cacheDirectory.appendingPathComponent("cache_metadata.json")

    // Create cache directory if needed
    try fileManager.createDirectory(
      at: self.cacheDirectory.rawValue,
      withIntermediateDirectories: true,
      attributes: nil
    )

    // Load existing metadata will be called when first accessed
  }

  // MARK: - CacheStorage Implementation

  public func get(_ key: CacheKey) async -> CachingMiddleware.CacheEntry? {
    await loadMetadataIfNeeded()
    guard let meta = metadata[key] else { return nil }
    guard await !removeExpiredEntryIfNeeded(for: key, metadata: meta) else { return nil }
    guard let data = await loadStoredData(for: key) else { return nil }
    guard validateChecksum(for: data, metadata: meta) else {
      await remove(key)
      return nil
    }

    return await deserializeCacheEntry(from: data, metadata: meta, key: key)
  }

  public func set(_ key: CacheKey, entry: CachingMiddleware.CacheEntry) async {
    await set(key, entry: entry, tags: [])
  }

  /// Enhanced set method with tag support
  public func set(_ key: CacheKey, entry: CachingMiddleware.CacheEntry, tags: [CacheTagName]) async
  {
    // Serialize response
    let serializableResponse = SerializableHTTPResponse(from: entry.response)
    guard let responseData = try? JSONEncoder().encode(serializableResponse) else {
      return
    }

    // Compress if enabled
    let dataToStore =
      compressionEnabled.rawValue ? responseData.gzipped() ?? responseData : responseData

    // Calculate checksum
    let checksum = dataToStore.sha256

    // Store to disk
    let dataFile = cacheDirectory.appendingPathComponent(sanitizeFilename(key))
    do {
      try dataToStore.write(to: dataFile.rawValue)
    } catch {
      return
    }

    // Update metadata
    let meta = DiskCacheMetadata(
      key: key,
      cachedAt: entry.cachedAt,
      expiresAt: entry.expiresAt,
      etag: entry.etag,
      lastModified: entry.lastModified,
      tags: tags,
      dataSize: StorageSizeBytes(Int64(dataToStore.count)),
      checksum: FileChecksum(checksum)
    )

    metadata[key] = meta

    // Update tag index
    for tag in tags {
      if tagIndex[tag] == nil {
        tagIndex[tag] = Set<CacheKey>()
      }
      tagIndex[tag]?.insert(key)
    }

    // Save metadata and enforce size
    await saveMetadata()
    await enforceSize()
  }

  public func remove(_ key: CacheKey) async {
    // Remove file
    let dataFile = cacheDirectory.appendingPathComponent(sanitizeFilename(key))
    try? fileManager.removeItem(at: dataFile.rawValue)

    // Clean up metadata and tag index
    if let meta = metadata.removeValue(forKey: key) {
      for tag in meta.tags {
        tagIndex[tag]?.remove(key)
        if tagIndex[tag]?.isEmpty == true {
          tagIndex.removeValue(forKey: tag)
        }
      }
    }

    await saveMetadata()
  }

  public func removeAll() async {
    // Remove all files
    if let contents = try? fileManager.contentsOfDirectory(
      at: cacheDirectory.rawValue,
      includingPropertiesForKeys: nil
    ) {
      for url in contents where url != metadataFile.rawValue {
        try? fileManager.removeItem(at: url)
      }
    }

    metadata.removeAll()
    tagIndex.removeAll()
    await saveMetadata()
  }

  public func removeExpired() async {
    let now = Date()
    let expiredKeys = metadata.compactMap { key, meta in
      now > meta.expiresAt ? key : nil
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

    let keysToRemove = metadata.keys.filter { key in
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

    case .maxDiskSize(let maxBytes):
      await enforceMaxDiskSize(maxBytes)

    case .combined(let entries, _):
      await enforceMaxEntries(entries)

    case .maxMemory:
      // Not applicable for disk cache
      break
    }
  }

  private func enforceMaxEntries(_ max: CacheEntryLimit) async {
    while metadata.count >= max.rawValue {
      guard let keyToEvict = selectOldestKey() else { break }
      await remove(keyToEvict)
    }
  }

  private func enforceMaxDiskSize(_ maxBytes: StorageSizeBytes) async {
    while getCurrentDiskUsage() > maxBytes {
      guard let keyToEvict = selectOldestKey() else { break }
      await remove(keyToEvict)
    }
  }

  private func selectOldestKey() -> CacheKey? {
    metadata.min { lhs, rhs in
      lhs.value.cachedAt < rhs.value.cachedAt
    }?.key
  }

  private func getCurrentDiskUsage() -> StorageSizeBytes {
    metadata.values.reduce(0) { $0 + $1.dataSize }
  }

  // MARK: - Metadata Management

  private func loadMetadata() async {
    guard fileManager.fileExists(atPath: metadataFile.path) else { return }

    do {
      let data = try Data(contentsOf: metadataFile.rawValue)
      let loadedMetadata = try JSONDecoder().decode([CacheKey: DiskCacheMetadata].self, from: data)
      self.metadata = loadedMetadata
      rebuildTagIndex(from: loadedMetadata)
    } catch {
      // Failed to load, start fresh
      self.metadata.removeAll()
      self.tagIndex.removeAll()
    }
  }

  private func saveMetadata() async {
    do {
      let data = try JSONEncoder().encode(metadata)
      try data.write(to: metadataFile.rawValue)
    } catch {
      // Failed to save metadata
    }
  }

  // MARK: - Utilities

  private func sanitizeFilename(_ filename: CacheKey) -> String {
    // Convert cache key to safe filename
    filename.rawValue
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: ":", with: "_")
      .replacingOccurrences(of: "?", with: "_")
      .replacingOccurrences(of: "#", with: "_")
      .prefix(255)  // Filesystem limit
      + ".cache"
  }

  /// Returns current disk usage in bytes
  public var diskUsage: StorageSizeBytes {
    get async { getCurrentDiskUsage() }
  }

  /// Returns cache directory URL
  public var cacheDirectoryURL: CacheDirectoryURL {
    cacheDirectory
  }
}
// swiftlint:enable type_body_length

private extension DiskCacheStorage {
  private func loadMetadataIfNeeded() async {
    guard metadata.isEmpty else { return }
    await loadMetadata()
  }

  private func removeExpiredEntryIfNeeded(
    for key: CacheKey,
    metadata: DiskCacheMetadata
  ) async -> Bool {
    guard Date() > metadata.expiresAt else {
      return false
    }

    await remove(key)
    return true
  }

  private func loadStoredData(for key: CacheKey) async -> Data? {
    let dataFile = cacheDirectory.appendingPathComponent(sanitizeFilename(key))
    guard let data = try? Data(contentsOf: dataFile.rawValue) else {
      await remove(key)
      return nil
    }

    return data
  }

  private func validateChecksum(for data: Data, metadata: DiskCacheMetadata) -> Bool {
    data.sha256 == metadata.checksum.rawValue
  }

  private func deserializeCacheEntry(
    from data: Data,
    metadata: DiskCacheMetadata,
    key: CacheKey
  ) async -> CachingMiddleware.CacheEntry? {
    let responseData = compressionEnabled.rawValue ? data.gunzipped() ?? data : data
    guard
      let response = try? JSONDecoder().decode(SerializableHTTPResponse.self, from: responseData)
    else {
      await remove(key)
      return nil
    }

    guard let httpResponse = response.toHTTPResponse() else {
      await remove(key)
      return nil
    }

    return CachingMiddleware.CacheEntry(
      response: httpResponse,
      ttl: CacheMaxAge(metadata.expiresAt.timeIntervalSinceNow),
      etag: metadata.etag,
      lastModified: metadata.lastModified
    )
  }

  private func rebuildTagIndex(from loadedMetadata: [CacheKey: DiskCacheMetadata]) {
    tagIndex.removeAll()

    for (key, meta) in loadedMetadata {
      for tag in meta.tags {
        if tagIndex[tag] == nil {
          tagIndex[tag] = Set<CacheKey>()
        }
        tagIndex[tag]?.insert(key)
      }
    }
  }
}
