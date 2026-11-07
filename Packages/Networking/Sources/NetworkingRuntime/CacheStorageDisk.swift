import Foundation
import NetworkingCore

/// Persistent response storage with checksums, optional compression, and tagged invalidation.
/// The supplied directory reserves `cache_metadata.json` and 64-character SHA-256 `.cache` files.
/// Entries are best effort: unreadable or corrupt cache data is discarded.
public actor DiskCacheStorage: HTTPResponseCacheStorage {
  let cacheDirectory: CacheDirectoryURL
  let metadataFile: CacheDirectoryURL
  var metadata: [CacheKey: DiskCacheMetadata] = [:]
  var tagIndex: [CacheTagName: Set<CacheKey>] = [:]
  var metadataLoaded = false
  let sizePolicy: CacheSizePolicy
  let compressionEnabled: CompressionEnabledFlag
  let fileManager = FileManager.default
  private let codec = JSONCodec()

  /// Creates storage; directory creation failures propagate to the caller.
  public init(
    cacheDirectory: CacheDirectoryURL? = nil,
    sizePolicy: CacheSizePolicy = .maxDiskSize(104_857_600),
    compressionEnabled: CompressionEnabledFlag = true
  ) throws {
    self.sizePolicy = sizePolicy
    self.compressionEnabled = compressionEnabled
    if let cacheDirectory {
      self.cacheDirectory = cacheDirectory
    } else {
      let directory = try FileManager.default.url(
        for: .cachesDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
      )
      self.cacheDirectory = CacheDirectoryURL(directory.appendingPathComponent("NetworkingCache"))
    }
    self.metadataFile = CacheDirectoryURL(
      self.cacheDirectory.rawValue.appendingPathComponent("cache_metadata.json")
    )
    try FileManager.default.createDirectory(
      at: self.cacheDirectory.rawValue,
      withIntermediateDirectories: true
    )
  }

}

extension DiskCacheStorage {
  func store(_ key: CacheKey, entry: CachingMiddleware.CacheEntry, tags: [CacheTagName]) {
    loadMetadataIfNeeded()
    guard let encoded = try? codec.encode(SerializableHTTPResponse(from: entry.response)) else {
      return
    }
    let compressed = compressionEnabled.rawValue ? encoded.compressedForCache() : nil
    let data = compressed ?? encoded
    do {
      try data.write(to: dataFile(key), options: .atomic)
    } catch { return }
    let updated = DiskCacheMetadata(
      key: key,
      cachedAt: entry.cachedAt,
      expiresAt: entry.expiresAt,
      etag: entry.etag,
      lastModified: entry.lastModified,
      tags: Array(Set(tags)),
      dataSize: StorageSizeBytes(Int64(data.count)),
      checksum: FileChecksum(data.sha256),
      compressed: compressed != nil
    )
    if let previous = metadata.updateValue(updated, forKey: key) {
      removeTagReferences(key, tags: previous.tags)
    }
    for tag in updated.tags { tagIndex[tag, default: []].insert(key) }
    enforceSize()
    saveMetadata()
  }

  func loadEntry(_ key: CacheKey, metadata: DiskCacheMetadata) -> CachingMiddleware.CacheEntry? {
    guard let data = try? Data(contentsOf: dataFile(key)),
      data.sha256 == metadata.checksum.rawValue,
      let response = decodeResponse(data, compressed: metadata.compressed)
    else {
      deleteEntries([key])
      return nil
    }
    var entry = CachingMiddleware.CacheEntry(
      response: response,
      ttl: CacheMaxAge(metadata.expiresAt.timeIntervalSinceNow),
      etag: metadata.etag,
      lastModified: metadata.lastModified
    )
    entry.tags = metadata.tags
    return entry
  }

  private func decodeResponse(_ data: Data, compressed: Bool) -> HTTPResponse? {
    let payload = compressed ? data.decompressedForCache() : data
    guard let payload else { return nil }
    return try? codec.decode(SerializableHTTPResponse.self, from: payload).toHTTPResponse()
  }

  func deleteEntries(_ keys: [CacheKey]) {
    guard !keys.isEmpty else { return }
    for key in Set(keys) { deleteEntry(key) }
    saveMetadata()
  }

  func deleteEntry(_ key: CacheKey) {
    try? fileManager.removeItem(at: dataFile(key))
    guard let previous = metadata.removeValue(forKey: key) else { return }
    removeTagReferences(key, tags: previous.tags)
  }

  private func removeTagReferences(_ key: CacheKey, tags: [CacheTagName]) {
    for tag in tags {
      tagIndex[tag]?.remove(key)
      if tagIndex[tag]?.isEmpty == true { tagIndex.removeValue(forKey: tag) }
    }
  }

  func dataFile(_ key: CacheKey) -> URL {
    cacheDirectory.rawValue.appendingPathComponent(Data(key.rawValue.utf8).sha256 + ".cache")
  }

  func saveMetadata() {
    guard let data = try? codec.encode(metadata) else { return }
    try? data.write(to: metadataFile.rawValue, options: .atomic)
  }

  func loadMetadataIfNeeded() {
    guard !metadataLoaded else { return }
    metadataLoaded = true
    let stored = readMetadata()
    metadata = stored.filter { fileManager.fileExists(atPath: dataFile($0.key).path) }
    tagIndex = metadata.reduce(into: [:]) { index, item in
      for tag in item.value.tags { index[tag, default: []].insert(item.key) }
    }
    let indexed = Set(metadata.keys.map { dataFile($0).lastPathComponent })
    for file in ownedDataFiles() where !indexed.contains(file.lastPathComponent) {
      try? fileManager.removeItem(at: file)
    }
    if metadata.count != stored.count { saveMetadata() }
  }

  private func readMetadata() -> [CacheKey: DiskCacheMetadata] {
    guard let data = try? Data(contentsOf: metadataFile.rawValue) else { return [:] }
    return (try? codec.decode([CacheKey: DiskCacheMetadata].self, from: data)) ?? [:]
  }

  func ownedDataFiles() -> [URL] {
    let files =
      (try? fileManager.contentsOfDirectory(
        at: cacheDirectory.rawValue,
        includingPropertiesForKeys: [.isRegularFileKey]
      )) ?? []
    return files.filter { isOwnedDataFile($0) }
  }

  private func isOwnedDataFile(_ file: URL) -> Bool {
    guard file.pathExtension == "cache",
      (try? file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
    else { return false }
    let stem = file.deletingPathExtension().lastPathComponent
    return stem.utf8.count == 64
      && stem.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
  }
}
