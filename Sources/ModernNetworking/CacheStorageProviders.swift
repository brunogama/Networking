import Foundation

// MARK: - Cache Policy and Expiration Strategies

/// Cache policy definitions for different storage strategies
public enum CachePolicy: Sendable {
  /// Least Recently Used eviction
  case lru
  /// Least Frequently Used eviction
  case lfu
  /// First In, First Out eviction
  case fifo
  /// Time-to-live based eviction only
  case ttlOnly
  /// Custom eviction strategy
  case custom(@Sendable (CachingMiddleware.CacheEntry, CachingMiddleware.CacheEntry) -> Bool)
}

/// Cache size management strategies
public enum CacheSizePolicy: Sendable {
  /// Maximum number of entries
  case maxEntries(Int)
  /// Maximum memory usage in bytes
  case maxMemory(Int64)
  /// Maximum disk usage in bytes
  case maxDiskSize(Int64)
  /// Combined entry and memory limits
  case combined(entries: Int, memory: Int64)
}

/// Cache expiration strategies
public struct ExpirationStrategy: Sendable {
  /// Default TTL for entries without explicit expiration
  public let defaultTTL: TimeInterval

  /// Maximum TTL allowed (caps explicit TTLs)
  public let maxTTL: TimeInterval

  /// Minimum TTL allowed (floors explicit TTLs)
  public let minTTL: TimeInterval

  /// Whether to extend TTL on cache hits
  public let extendOnAccess: Bool

  /// Factor to extend TTL by when extending on access (0.0-1.0)
  public let extensionFactor: Double

  public init(
    defaultTTL: TimeInterval = 300.0,
    maxTTL: TimeInterval = 3600.0,
    minTTL: TimeInterval = 60.0,
    extendOnAccess: Bool = false,
    extensionFactor: Double = 0.5
  ) {
    self.defaultTTL = defaultTTL
    self.maxTTL = maxTTL
    self.minTTL = minTTL
    self.extendOnAccess = extendOnAccess
    self.extensionFactor = max(0.0, min(1.0, extensionFactor))
  }
}

// MARK: - Enhanced Memory Cache Storage

/// Advanced in-memory cache storage with sophisticated eviction policies
public actor AdvancedMemoryCacheStorage: CachingMiddleware.CacheStorage {
  // MARK: - Cache Entry Wrapper

  /// Internal wrapper for cache entries with access metadata
  private struct MemoryCacheEntry: Sendable {
    let cacheEntry: CachingMiddleware.CacheEntry
    let accessCount: Int
    let lastAccessTime: Date
    let tags: Set<String>

    init(
      cacheEntry: CachingMiddleware.CacheEntry,
      accessCount: Int = 0,
      lastAccessTime: Date = Date(),
      tags: Set<String> = []
    ) {
      self.cacheEntry = cacheEntry
      self.accessCount = accessCount
      self.lastAccessTime = lastAccessTime
      self.tags = tags
    }

    func incrementAccess() -> MemoryCacheEntry {
      MemoryCacheEntry(
        cacheEntry: cacheEntry,
        accessCount: accessCount + 1,
        lastAccessTime: Date(),
        tags: tags
      )
    }
  }

  // MARK: - Properties

  private var cache: [String: MemoryCacheEntry] = [:]
  private var tagIndex: [String: Set<String>] = [:]  // tag -> cache keys
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

  public func get(_ key: String) async -> CachingMiddleware.CacheEntry? {
    if let wrapper = cache[key] {
      // Check expiration
      if wrapper.cacheEntry.isExpired {
        await remove(key)
        missCount += 1
        return nil
      }

      // Update access metadata
      let updatedWrapper = wrapper.incrementAccess()
      cache[key] = updatedWrapper

      // Extend TTL if configured
      if expirationStrategy.extendOnAccess {
        let extendedEntry = extendTTL(wrapper.cacheEntry)
        let finalWrapper = MemoryCacheEntry(
          cacheEntry: extendedEntry,
          accessCount: updatedWrapper.accessCount,
          lastAccessTime: updatedWrapper.lastAccessTime,
          tags: updatedWrapper.tags
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

  public func set(_ key: String, entry: CachingMiddleware.CacheEntry) async {
    await set(key, entry: entry, tags: [])
  }

  /// Enhanced set method with tag support
  public func set(_ key: String, entry: CachingMiddleware.CacheEntry, tags: [String]) async {
    // Enforce size limits before adding
    await enforceSize()

    // Create wrapper with tags
    let tagSet = Set(tags)
    let wrapper = MemoryCacheEntry(
      cacheEntry: entry,
      tags: tagSet
    )

    // Update cache and tag index
    cache[key] = wrapper

    // Update tag index
    for tag in tagSet {
      if tagIndex[tag] == nil {
        tagIndex[tag] = Set<String>()
      }
      tagIndex[tag]?.insert(key)
    }
  }

  public func remove(_ key: String) async {
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
    hitCount = 0
    missCount = 0
    evictionCount = 0
  }

  public func removeExpired() async {
    let expiredKeys = cache.compactMap { key, wrapper in
      wrapper.cacheEntry.isExpired ? key : nil
    }

    for key in expiredKeys {
      await remove(key)
    }
  }

  public func removeByTags(_ tags: [String]) async {
    var keysToRemove = Set<String>()

    for tag in tags {
      if let taggedKeys = tagIndex[tag] {
        keysToRemove.formUnion(taggedKeys)
      }
    }

    for key in keysToRemove {
      await remove(key)
    }
  }

  public func removeByPattern(_ pattern: String) async {
    let regex: NSRegularExpression?
    do {
      let regexPattern =
        pattern
        .replacingOccurrences(of: "*", with: ".*")
        .replacingOccurrences(of: "?", with: ".")
      regex = try NSRegularExpression(pattern: regexPattern, options: [])
    } catch {
      return
    }

    guard let regex = regex else { return }

    let keysToRemove = cache.keys.filter { key in
      let range = NSRange(location: 0, length: key.utf16.count)
      return regex.firstMatch(in: key, options: [], range: range) != nil
    }

    for key in keysToRemove {
      await remove(key)
    }
  }

  public func removeByKeys(_ keys: [String]) async {
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

  private func enforceMaxEntries(_ max: Int) async {
    while cache.count >= max {
      guard let keyToEvict = await selectKeyForEviction() else { break }
      await remove(keyToEvict)
      evictionCount += 1
    }
  }

  private func enforceMaxMemory(_ maxBytes: Int64) async {
    let currentSize = estimateMemoryUsage()
    if currentSize <= maxBytes { return }

    while estimateMemoryUsage() > maxBytes {
      guard let keyToEvict = await selectKeyForEviction() else { break }
      await remove(keyToEvict)
      evictionCount += 1
    }
  }

  private func selectKeyForEviction() async -> String? {
    switch policy {
    case .lru:
      return cache.min { lhs, rhs in
        lhs.value.lastAccessTime < rhs.value.lastAccessTime
      }?.key

    case .lfu:
      return cache.min { lhs, rhs in
        lhs.value.accessCount < rhs.value.accessCount
      }?.key

    case .fifo:
      return cache.min { lhs, rhs in
        lhs.value.cacheEntry.cachedAt < rhs.value.cacheEntry.cachedAt
      }?.key

    case .ttlOnly:
      // Remove entries closest to expiration
      return cache.min { lhs, rhs in
        lhs.value.cacheEntry.expiresAt < rhs.value.cacheEntry.expiresAt
      }?.key

    case .custom(let comparator):
      return cache.min { lhs, rhs in
        comparator(lhs.value.cacheEntry, rhs.value.cacheEntry)
      }?.key
    }
  }

  private func estimateMemoryUsage() -> Int64 {
    // Rough estimation of memory usage
    Int64(cache.count * 1024)  // Assume ~1KB per entry average
  }

  // MARK: - TTL Management

  private func extendTTL(_ entry: CachingMiddleware.CacheEntry) -> CachingMiddleware.CacheEntry {
    let currentAge = entry.age
    let originalTTL = entry.expiresAt.timeIntervalSince(entry.cachedAt)
    let extensionTime = originalTTL * expirationStrategy.extensionFactor
    let newTTL = min(originalTTL + extensionTime, expirationStrategy.maxTTL)

    return CachingMiddleware.CacheEntry(
      response: entry.response,
      ttl: newTTL - currentAge,
      etag: entry.etag,
      lastModified: entry.lastModified
    )
  }

  // MARK: - Metrics and Debugging

  /// Returns cache performance metrics
  public func getMetrics() async -> CacheMetrics {
    CacheMetrics(
      size: cache.count,
      hitCount: hitCount,
      missCount: missCount,
      evictionCount: evictionCount,
      hitRatio: hitCount + missCount > 0 ? Double(hitCount) / Double(hitCount + missCount) : 0.0
    )
  }

  /// Returns estimated memory usage in bytes
  public var estimatedMemoryUsage: Int64 {
    get async { estimateMemoryUsage() }
  }
}

// MARK: - Disk Cache Storage

/// Persistent disk-based cache storage with compression and integrity checks
public actor DiskCacheStorage: CachingMiddleware.CacheStorage {
  // MARK: - Disk Cache Entry

  private struct DiskCacheMetadata: Codable, Sendable {
    let key: String
    let cachedAt: Date
    let expiresAt: Date
    let etag: String?
    let lastModified: String?
    let tags: [String]
    let dataSize: Int64
    let checksum: String
  }

  // MARK: - Properties

  private let cacheDirectory: URL
  private let metadataFile: URL
  private var metadata: [String: DiskCacheMetadata] = [:]
  private var tagIndex: [String: Set<String>] = [:]
  private let sizePolicy: CacheSizePolicy
  private let expirationStrategy: ExpirationStrategy
  private let compressionEnabled: Bool
  private let fileManager = FileManager.default

  // MARK: - Initialization

  public init(
    cacheDirectory: URL? = nil,
    sizePolicy: CacheSizePolicy = .maxDiskSize(100 * 1024 * 1024),  // 100MB
    expirationStrategy: ExpirationStrategy = ExpirationStrategy(),
    compressionEnabled: Bool = true
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
      self.cacheDirectory = appSupport.appendingPathComponent("ModernNetworkingCache")
    }

    self.metadataFile = self.cacheDirectory.appendingPathComponent("cache_metadata.json")

    // Create cache directory if needed
    try fileManager.createDirectory(
      at: self.cacheDirectory,
      withIntermediateDirectories: true,
      attributes: nil
    )

    // Load existing metadata will be called when first accessed
  }

  // MARK: - CacheStorage Implementation

  public func get(_ key: String) async -> CachingMiddleware.CacheEntry? {
    // Load metadata if not already loaded
    if metadata.isEmpty {
      await loadMetadata()
    }

    guard let meta = metadata[key] else { return nil }

    // Check expiration
    if Date() > meta.expiresAt {
      await remove(key)
      return nil
    }

    // Load from disk
    let dataFile = cacheDirectory.appendingPathComponent(sanitizeFilename(key))

    guard let data = try? Data(contentsOf: dataFile) else {
      // File missing, clean up metadata
      await remove(key)
      return nil
    }

    // Verify integrity
    let checksum = data.sha256
    guard checksum == meta.checksum else {
      // Corrupted file, remove
      await remove(key)
      return nil
    }

    // Decompress if needed
    let responseData = compressionEnabled ? data.gunzipped() ?? data : data

    // Deserialize response
    guard
      let response = try? JSONDecoder().decode(SerializableHTTPResponse.self, from: responseData)
    else {
      await remove(key)
      return nil
    }

    return CachingMiddleware.CacheEntry(
      response: response.toHTTPResponse(),
      ttl: meta.expiresAt.timeIntervalSinceNow,
      etag: meta.etag,
      lastModified: meta.lastModified
    )
  }

  public func set(_ key: String, entry: CachingMiddleware.CacheEntry) async {
    await set(key, entry: entry, tags: [])
  }

  /// Enhanced set method with tag support
  public func set(_ key: String, entry: CachingMiddleware.CacheEntry, tags: [String]) async {
    // Serialize response
    let serializableResponse = SerializableHTTPResponse(from: entry.response)
    guard let responseData = try? JSONEncoder().encode(serializableResponse) else {
      return
    }

    // Compress if enabled
    let dataToStore = compressionEnabled ? responseData.gzipped() ?? responseData : responseData

    // Calculate checksum
    let checksum = dataToStore.sha256

    // Store to disk
    let dataFile = cacheDirectory.appendingPathComponent(sanitizeFilename(key))
    do {
      try dataToStore.write(to: dataFile)
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
      dataSize: Int64(dataToStore.count),
      checksum: checksum
    )

    metadata[key] = meta

    // Update tag index
    for tag in tags {
      if tagIndex[tag] == nil {
        tagIndex[tag] = Set<String>()
      }
      tagIndex[tag]?.insert(key)
    }

    // Save metadata and enforce size
    await saveMetadata()
    await enforceSize()
  }

  public func remove(_ key: String) async {
    // Remove file
    let dataFile = cacheDirectory.appendingPathComponent(sanitizeFilename(key))
    try? fileManager.removeItem(at: dataFile)

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
      at: cacheDirectory,
      includingPropertiesForKeys: nil
    ) {
      for url in contents where url != metadataFile {
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

  public func removeByTags(_ tags: [String]) async {
    var keysToRemove = Set<String>()

    for tag in tags {
      if let taggedKeys = tagIndex[tag] {
        keysToRemove.formUnion(taggedKeys)
      }
    }

    for key in keysToRemove {
      await remove(key)
    }
  }

  public func removeByPattern(_ pattern: String) async {
    let regex: NSRegularExpression?
    do {
      let regexPattern =
        pattern
        .replacingOccurrences(of: "*", with: ".*")
        .replacingOccurrences(of: "?", with: ".")
      regex = try NSRegularExpression(pattern: regexPattern, options: [])
    } catch {
      return
    }

    guard let regex = regex else { return }

    let keysToRemove = metadata.keys.filter { key in
      let range = NSRange(location: 0, length: key.utf16.count)
      return regex.firstMatch(in: key, options: [], range: range) != nil
    }

    for key in keysToRemove {
      await remove(key)
    }
  }

  public func removeByKeys(_ keys: [String]) async {
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

  private func enforceMaxEntries(_ max: Int) async {
    while metadata.count >= max {
      guard let keyToEvict = selectOldestKey() else { break }
      await remove(keyToEvict)
    }
  }

  private func enforceMaxDiskSize(_ maxBytes: Int64) async {
    while getCurrentDiskUsage() > maxBytes {
      guard let keyToEvict = selectOldestKey() else { break }
      await remove(keyToEvict)
    }
  }

  private func selectOldestKey() -> String? {
    metadata.min { lhs, rhs in
      lhs.value.cachedAt < rhs.value.cachedAt
    }?.key
  }

  private func getCurrentDiskUsage() -> Int64 {
    metadata.values.reduce(0) { $0 + $1.dataSize }
  }

  // MARK: - Metadata Management

  private func loadMetadata() async {
    guard fileManager.fileExists(atPath: metadataFile.path) else { return }

    do {
      let data = try Data(contentsOf: metadataFile)
      let loadedMetadata = try JSONDecoder().decode([String: DiskCacheMetadata].self, from: data)
      self.metadata = loadedMetadata

      // Rebuild tag index
      self.tagIndex.removeAll()
      for (key, meta) in loadedMetadata {
        for tag in meta.tags {
          if tagIndex[tag] == nil {
            tagIndex[tag] = Set<String>()
          }
          tagIndex[tag]?.insert(key)
        }
      }
    } catch {
      // Failed to load, start fresh
      self.metadata.removeAll()
      self.tagIndex.removeAll()
    }
  }

  private func saveMetadata() async {
    do {
      let data = try JSONEncoder().encode(metadata)
      try data.write(to: metadataFile)
    } catch {
      // Failed to save metadata
    }
  }

  // MARK: - Utilities

  private func sanitizeFilename(_ filename: String) -> String {
    // Convert cache key to safe filename
    filename
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: ":", with: "_")
      .replacingOccurrences(of: "?", with: "_")
      .replacingOccurrences(of: "#", with: "_")
      .prefix(255)  // Filesystem limit
      + ".cache"
  }

  /// Returns current disk usage in bytes
  public var diskUsage: Int64 {
    get async { getCurrentDiskUsage() }
  }

  /// Returns cache directory URL
  public var cacheDirectoryURL: URL {
    cacheDirectory
  }
}

// MARK: - Hybrid Cache Storage

/// Combines memory and disk caching for optimal performance
public actor HybridCacheStorage: CachingMiddleware.CacheStorage {
  private let memoryCache: AdvancedMemoryCacheStorage
  private let diskCache: DiskCacheStorage
  private let memoryThreshold: Int64  // Entries larger than this go directly to disk

  public init(
    memorySizePolicy: CacheSizePolicy = .maxEntries(500),
    diskSizePolicy: CacheSizePolicy = .maxDiskSize(50 * 1024 * 1024),
    memoryThreshold: Int64 = 10 * 1024,  // 10KB
    cacheDirectory: URL? = nil
  ) throws {
    self.memoryCache = AdvancedMemoryCacheStorage(
      policy: .lru,
      sizePolicy: memorySizePolicy
    )
    self.diskCache = try DiskCacheStorage(
      cacheDirectory: cacheDirectory,
      sizePolicy: diskSizePolicy
    )
    self.memoryThreshold = memoryThreshold
  }

  public func get(_ key: String) async -> CachingMiddleware.CacheEntry? {
    // Try memory first
    if let entry = await memoryCache.get(key) {
      return entry
    }

    // Try disk
    if let entry = await diskCache.get(key) {
      // Promote to memory if small enough
      let responseSize = estimateResponseSize(entry.response)
      if responseSize <= memoryThreshold {
        await memoryCache.set(key, entry: entry)
      }
      return entry
    }

    return nil
  }

  public func set(_ key: String, entry: CachingMiddleware.CacheEntry) async {
    let responseSize = estimateResponseSize(entry.response)

    if responseSize <= memoryThreshold {
      // Small enough for memory
      await memoryCache.set(key, entry: entry)
    } else {
      // Too large, store on disk
      await diskCache.set(key, entry: entry)
    }
  }

  public func remove(_ key: String) async {
    await memoryCache.remove(key)
    await diskCache.remove(key)
  }

  public func removeAll() async {
    await memoryCache.removeAll()
    await diskCache.removeAll()
  }

  public func removeExpired() async {
    await memoryCache.removeExpired()
    await diskCache.removeExpired()
  }

  public func removeByTags(_ tags: [String]) async {
    await memoryCache.removeByTags(tags)
    await diskCache.removeByTags(tags)
  }

  public func removeByPattern(_ pattern: String) async {
    await memoryCache.removeByPattern(pattern)
    await diskCache.removeByPattern(pattern)
  }

  public func removeByKeys(_ keys: [String]) async {
    await memoryCache.removeByKeys(keys)
    await diskCache.removeByKeys(keys)
  }

  private func estimateResponseSize(_ response: HTTPResponse) -> Int64 {
    var size: Int64 = 0

    // Headers
    for (key, value) in response.headers {
      size += Int64(key.utf8.count + value.utf8.count)
    }

    // Body
    if let body = response.body {
      size += Int64(body.count)
    }

    return size
  }

  /// Returns combined cache metrics
  public func getMetrics() async -> (memory: CacheMetrics, disk: Int64) {
    let memoryMetrics = await memoryCache.getMetrics()
    let diskUsage = await diskCache.diskUsage
    return (memory: memoryMetrics, disk: diskUsage)
  }
}

// MARK: - Supporting Types

/// Cache performance metrics
public struct CacheMetrics: Sendable {
  public let size: Int
  public let hitCount: Int64
  public let missCount: Int64
  public let evictionCount: Int64
  public let hitRatio: Double

  public init(size: Int, hitCount: Int64, missCount: Int64, evictionCount: Int64, hitRatio: Double)
  {
    self.size = size
    self.hitCount = hitCount
    self.missCount = missCount
    self.evictionCount = evictionCount
    self.hitRatio = hitRatio
  }
}

/// Serializable version of HTTPResponse for disk storage
private struct SerializableHTTPResponse: Codable {
  let statusCode: Int
  let headers: [String: String]
  let body: Data?
  let requestURL: String

  init(from response: HTTPResponse) {
    self.statusCode = response.status.rawValue
    self.headers = response.headers
    self.body = response.body
    self.requestURL = response.request.url.absoluteString
  }

  func toHTTPResponse() -> HTTPResponse {
    // Create a minimal request for deserialization
    guard let url = URL(string: requestURL) else {
      fatalError("Invalid URL in serialized response")
    }

    let request = HTTPRequest(
      method: .get,
      url: url,
      headers: [:],
      body: nil,
      timeout: 30.0
    )

    return HTTPResponse(
      request: request,
      status: HTTPStatus(rawValue: statusCode),
      headers: headers,
      body: body
    )
  }
}

// MARK: - Data Extensions

private extension Data {
  var sha256: String {
    let digest = SHA256.hash(data: self)
    return digest.compactMap { String(format: "%02x", $0) }.joined()
  }

  func gzipped() -> Data? {
    // Placeholder for gzip compression
    // In a real implementation, use a compression library
    self
  }

  func gunzipped() -> Data? {
    // Placeholder for gzip decompression
    // In a real implementation, use a decompression library
    self
  }
}

private struct SHA256 {
  static func hash(data: Data) -> Data {
    // Placeholder for SHA256 hashing
    // In a real implementation, use CryptoKit or CommonCrypto
    Data(repeating: 0, count: 32)
  }
}
