import Foundation

// MARK: - Cache Metadata

/// Cache configuration metadata extracted from method attributes
public struct CacheMetadata: Sendable {
  public let ttl: TimeInterval?
  public let tags: [String]
  public let customKey: String?
  public let isInvalidating: Bool
  public let invalidationTags: [String]
  public let invalidationPattern: String?
  public let invalidationKeys: [String]

  public init(
    ttl: TimeInterval? = nil,
    tags: [String] = [],
    customKey: String? = nil,
    isInvalidating: Bool = false,
    invalidationTags: [String] = [],
    invalidationPattern: String? = nil,
    invalidationKeys: [String] = []
  ) {
    self.ttl = ttl
    self.tags = tags
    self.customKey = customKey
    self.isInvalidating = isInvalidating
    self.invalidationTags = invalidationTags
    self.invalidationPattern = invalidationPattern
    self.invalidationKeys = invalidationKeys
  }
}

/// Middleware that provides response caching with TTL, cache invalidation, and flexible storage strategies.
public actor CachingMiddleware: HTTPRequestMiddleware, HTTPResponseMiddleware {
  // MARK: - Cache Entry

  /// A cached response entry with metadata
  public struct CacheEntry: Sendable {
    public let response: HTTPResponse
    public let cachedAt: Date
    public let expiresAt: Date
    public let etag: String?
    public let lastModified: String?

    internal init(
      response: HTTPResponse,
      ttl: TimeInterval,
      etag: String? = nil,
      lastModified: String? = nil
    ) {
      self.response = response
      self.cachedAt = Date()
      self.expiresAt = Date().addingTimeInterval(ttl)
      self.etag = etag
      self.lastModified = lastModified
    }

    /// Returns true if the cache entry has expired
    public var isExpired: Bool {
      Date() > expiresAt
    }

    /// Returns the age of the cache entry in seconds
    public var age: TimeInterval {
      Date().timeIntervalSince(cachedAt)
    }
  }

  // MARK: - Cache Storage Protocol

  /// Protocol for cache storage implementations
  public protocol CacheStorage: Sendable {
    /// Retrieves a cached entry for the given key
    func get(_ key: String) async -> CacheEntry?

    /// Stores a cache entry with the given key
    func set(_ key: String, entry: CacheEntry) async

    /// Removes a cached entry for the given key
    func remove(_ key: String) async

    /// Removes all cached entries
    func removeAll() async

    /// Removes expired entries
    func removeExpired() async

    /// Removes cached entries by tags (for advanced storage implementations)
    func removeByTags(_ tags: [String]) async

    /// Removes cached entries matching a pattern (for advanced storage implementations)
    func removeByPattern(_ pattern: String) async

    /// Removes specific keys (for advanced storage implementations)
    func removeByKeys(_ keys: [String]) async
  }

  // MARK: - Configuration

  /// Configuration for caching behavior
  public struct Configuration: Sendable {
    /// Default time-to-live for cached responses
    public let defaultTTL: TimeInterval

    /// Maximum size of the cache storage
    public let maxCacheSize: Int?

    /// Predicate to determine if a request should be cached
    public let shouldCache: @Sendable (HTTPRequest, HTTPResponse) -> Bool

    /// Function to generate cache keys from requests
    public let cacheKeyGenerator: @Sendable (HTTPRequest) -> String

    /// Function to generate cache keys with metadata support
    public let intelligentCacheKeyGenerator: @Sendable (HTTPRequest, CacheMetadata?) -> String

    /// Function to determine TTL for specific responses
    public let ttlCalculator: @Sendable (HTTPRequest, HTTPResponse) -> TimeInterval

    /// Function to extract cache metadata from request attributes
    public let metadataExtractor: @Sendable (HTTPRequest) -> CacheMetadata?

    /// Whether to use conditional requests (If-None-Match, If-Modified-Since)
    public let useConditionalRequests: Bool

    public init(
      defaultTTL: TimeInterval = 300.0,  // 5 minutes
      maxCacheSize: Int? = 100,
      shouldCache: @escaping @Sendable (HTTPRequest, HTTPResponse) -> Bool = Self
        .defaultShouldCache,
      cacheKeyGenerator: @escaping @Sendable (HTTPRequest) -> String = Self.defaultCacheKey,
      intelligentCacheKeyGenerator: @escaping @Sendable (HTTPRequest, CacheMetadata?) -> String =
        Self.defaultIntelligentCacheKey,
      ttlCalculator: @escaping @Sendable (HTTPRequest, HTTPResponse) -> TimeInterval = Self
        .defaultTTLCalculator,
      metadataExtractor: @escaping @Sendable (HTTPRequest) -> CacheMetadata? = Self
        .defaultMetadataExtractor,
      useConditionalRequests: Bool = true
    ) {
      self.defaultTTL = defaultTTL
      self.maxCacheSize = maxCacheSize
      self.shouldCache = shouldCache
      self.cacheKeyGenerator = cacheKeyGenerator
      self.intelligentCacheKeyGenerator = intelligentCacheKeyGenerator
      self.ttlCalculator = ttlCalculator
      self.metadataExtractor = metadataExtractor
      self.useConditionalRequests = useConditionalRequests
    }

    /// Default predicate for determining if a response should be cached
    public static func defaultShouldCache(_ request: HTTPRequest, _ response: HTTPResponse) -> Bool
    {
      // Only cache GET requests
      guard request.method == .get else { return false }

      // Only cache successful responses
      guard response.status.isSuccess else { return false }

      // Don't cache responses with Cache-Control: no-cache or no-store
      if let cacheControl = response.headers["Cache-Control"]?.lowercased() {
        if cacheControl.contains("no-cache") || cacheControl.contains("no-store") {
          return false
        }
      }

      return true
    }

    /// Default cache key generator
    public static func defaultCacheKey(_ request: HTTPRequest) -> String {
      "\(request.method.rawValue):\(request.url.absoluteString)"
    }

    /// Intelligent cache key generator that considers metadata
    public static func defaultIntelligentCacheKey(
      _ request: HTTPRequest,
      _ metadata: CacheMetadata?
    ) -> String {
      // Use custom key if provided
      if let customKey = metadata?.customKey {
        return customKey
      }

      // Generate normalized URL key
      var components = URLComponents(url: request.url, resolvingAgainstBaseURL: false)

      // Sort query items for consistent caching
      if let queryItems = components?.queryItems {
        components?.queryItems = queryItems.sorted { $0.name < $1.name }
      }

      let normalizedURL = components?.url?.absoluteString ?? request.url.absoluteString

      // Include tags in key for better cache segmentation
      let tagsHash = metadata?.tags.sorted().joined(separator: ",").hashValue

      return "\(request.method.rawValue):\(normalizedURL):\(tagsHash ?? 0)"
    }

    /// Default metadata extractor (placeholder for macro-generated code)
    public static func defaultMetadataExtractor(_ request: HTTPRequest) -> CacheMetadata? {
      // In a real implementation, this would extract metadata from method attributes
      // For now, return nil to use default behavior
      nil
    }

    /// Default TTL calculator that respects Cache-Control headers
    public static func defaultTTLCalculator(
      _ request: HTTPRequest,
      _ response: HTTPResponse
    ) -> TimeInterval {
      // Check for Cache-Control max-age
      if let cacheControl = response.headers["Cache-Control"] {
        let components = cacheControl.lowercased().components(separatedBy: ",")
        for component in components {
          let trimmed = component.trimmingCharacters(in: .whitespaces)
          if trimmed.hasPrefix("max-age=") {
            let maxAgeString = String(trimmed.dropFirst(8))
            if let maxAge = TimeInterval(maxAgeString) {
              return maxAge
            }
          }
        }
      }

      // Check for Expires header
      if let expiresString = response.headers["Expires"] {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        if let expiresDate = formatter.date(from: expiresString) {
          let ttl = expiresDate.timeIntervalSinceNow
          return max(ttl, 0)  // Don't return negative TTL
        }
      }

      // Default TTL
      return 300.0  // 5 minutes
    }
  }

  // MARK: - Properties

  private let configuration: Configuration
  private let storage: any CacheStorage
  private let client: any HTTPClient

  // MARK: - Initialization

  /// Creates a new caching middleware
  /// - Parameters:
  ///   - configuration: The caching configuration
  ///   - storage: The cache storage implementation
  ///   - client: The HTTP client to use for requests
  public init(
    configuration: Configuration,
    storage: any CacheStorage,
    client: any HTTPClient
  ) {
    self.configuration = configuration
    self.storage = storage
    self.client = client
  }

  // MARK: - HTTPRequestMiddleware

  public func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
    // For cacheable requests, check if we have a cached entry
    guard request.method == .get else { return request }

    // Extract cache metadata
    let metadata = configuration.metadataExtractor(request)
    let cacheKey = configuration.intelligentCacheKeyGenerator(request, metadata)

    if let cachedEntry = await storage.get(cacheKey) {
      if !cachedEntry.isExpired {
        // We have a valid cached response, but we might want to use conditional requests
        if configuration.useConditionalRequests {
          return addConditionalHeaders(to: request, entry: cachedEntry)
        }
      }
    }

    return request
  }

  // MARK: - HTTPResponseMiddleware

  public func processResponse(
    _ response: HTTPResponse,
    for request: HTTPRequest
  ) async throws -> HTTPResponse {
    // Extract cache metadata
    let metadata = configuration.metadataExtractor(request)

    // Handle cache invalidation first
    if let metadata = metadata, metadata.isInvalidating {
      await handleCacheInvalidation(metadata: metadata)
    }

    let cacheKey = configuration.intelligentCacheKeyGenerator(request, metadata)

    // Handle 304 Not Modified responses
    if response.status.rawValue == 304 {
      if let cachedEntry = await storage.get(cacheKey) {
        // Return the cached response but update its expiration
        let ttl = determineTTL(request: request, response: response, metadata: metadata)
        let updatedEntry = CacheEntry(
          response: cachedEntry.response,
          ttl: ttl,
          etag: cachedEntry.etag,
          lastModified: cachedEntry.lastModified
        )
        await storage.set(cacheKey, entry: updatedEntry)
        return cachedEntry.response
      }
    }

    // Check if we should cache this response
    if shouldCacheResponse(request: request, response: response, metadata: metadata) {
      let ttl = determineTTL(request: request, response: response, metadata: metadata)

      let entry = CacheEntry(
        response: response,
        ttl: ttl,
        etag: response.headers["ETag"],
        lastModified: response.headers["Last-Modified"]
      )

      await storage.set(cacheKey, entry: entry)
    }

    return response
  }

  // MARK: - Public Cache Management

  /// Clears all cached entries
  public func clearCache() async {
    await storage.removeAll()
  }

  /// Removes expired entries from the cache
  public func cleanExpiredEntries() async {
    await storage.removeExpired()
  }

  /// Invalidates cache entries matching a predicate
  /// - Parameter predicate: Function to determine which entries to invalidate
  public func invalidateEntries(matching predicate: @Sendable (String) -> Bool) async {
    // This is a simplified implementation. A full implementation would require
    // the storage to support enumeration of keys.
    // For now, we'll just clear all entries if needed
  }

  /// Gets a cached entry for debugging/inspection
  /// - Parameter request: The request to get cached entry for
  /// - Returns: The cached entry if available
  public func getCachedEntry(for request: HTTPRequest) async -> CacheEntry? {
    let metadata = configuration.metadataExtractor(request)
    let cacheKey = configuration.intelligentCacheKeyGenerator(request, metadata)
    return await storage.get(cacheKey)
  }

  /// Invalidates cache entries by tags
  /// - Parameter tags: Tags to invalidate
  public func invalidateByTags(_ tags: [String]) async {
    await storage.removeByTags(tags)
  }

  /// Invalidates cache entries by pattern
  /// - Parameter pattern: Pattern to match against cache keys
  public func invalidateByPattern(_ pattern: String) async {
    await storage.removeByPattern(pattern)
  }

  /// Invalidates specific cache keys
  /// - Parameter keys: Keys to invalidate
  public func invalidateByKeys(_ keys: [String]) async {
    await storage.removeByKeys(keys)
  }

  // MARK: - Cache Warming and Prefetching

  /// Warms the cache by prefetching data for specified requests
  /// - Parameter requests: Array of requests to prefetch
  /// - Parameter concurrency: Maximum concurrent prefetch operations
  /// - Returns: Array of results indicating success/failure for each request
  public func warmCache(
    requests: [HTTPRequest],
    concurrency: Int = 4
  ) async -> [WarmCacheResult] {
    let semaphore = AsyncSemaphore(value: concurrency)

    return await withTaskGroup(of: (Int, WarmCacheResult).self) { group in
      // Schedule all prefetch tasks
      for (index, request) in requests.enumerated() {
        group.addTask {
          await semaphore.wait()

          let result = await self.prefetchSingle(request: request)
          await semaphore.signal()

          return (index, result)
        }
      }

      // Collect results in order
      var results = [WarmCacheResult?](repeating: nil, count: requests.count)
      for await (index, result) in group {
        results[index] = result
      }

      return results.compactMap { $0 }
    }
  }

  /// Prefetches a single request and stores it in cache
  /// - Parameter request: The request to prefetch
  /// - Returns: Result indicating success or failure
  public func prefetchSingle(request: HTTPRequest) async -> WarmCacheResult {
    do {
      // Check if already cached and fresh
      let metadata = configuration.metadataExtractor(request)
      let cacheKey = configuration.intelligentCacheKeyGenerator(request, metadata)

      if let existingEntry = await storage.get(cacheKey), !existingEntry.isExpired {
        return .alreadyCached(key: cacheKey)
      }

      // Execute the request
      let response = try await client.execute(request)

      // Process and cache the response
      let processedResponse = try await processResponse(response, for: request)

      return .success(key: cacheKey, response: processedResponse)
    } catch {
      return .failure(request: request, error: error)
    }
  }

  /// Preloads cache entries based on access patterns
  /// - Parameter patterns: Cache access patterns to preload
  /// - Parameter strategy: Preloading strategy to use
  public func preloadCache(
    patterns: [CachePreloadPattern],
    strategy: CachePreloadStrategy = .sequential
  ) async {
    switch strategy {
    case .sequential:
      for pattern in patterns {
        await executePreloadPattern(pattern)
      }

    case .concurrent(let maxConcurrency):
      await withTaskGroup(of: Void.self) { group in
        let semaphore = AsyncSemaphore(value: maxConcurrency)

        for pattern in patterns {
          group.addTask {
            await semaphore.wait()
            await self.executePreloadPattern(pattern)
            await semaphore.signal()
          }
        }
      }

    case .prioritized:
      let sortedPatterns = patterns.sorted { lhs, rhs in
        lhs.priority > rhs.priority
      }

      for pattern in sortedPatterns {
        await executePreloadPattern(pattern)
      }
    }
  }

  /// Intelligently prefetches related content based on current request
  /// - Parameter request: The current request
  /// - Parameter depth: How many levels of related content to prefetch
  /// - Returns: Number of items prefetched
  @discardableResult
  public func intelligentPrefetch(
    basedOn request: HTTPRequest,
    depth: Int = 1
  ) async -> Int {
    guard depth > 0 else { return 0 }

    var prefetchedCount = 0
    let relatedRequests = generateRelatedRequests(from: request, depth: depth)

    for relatedRequest in relatedRequests {
      let result = await prefetchSingle(request: relatedRequest)
      if case .success = result {
        prefetchedCount += 1
      }
    }

    return prefetchedCount
  }

  // MARK: - Private Methods

  /// Handles cache invalidation based on metadata
  private func handleCacheInvalidation(metadata: CacheMetadata) async {
    // Invalidate by tags
    if !metadata.invalidationTags.isEmpty {
      await storage.removeByTags(metadata.invalidationTags)
    }

    // Invalidate by pattern
    if let pattern = metadata.invalidationPattern {
      await storage.removeByPattern(pattern)
    }

    // Invalidate specific keys
    if !metadata.invalidationKeys.isEmpty {
      await storage.removeByKeys(metadata.invalidationKeys)
    }
  }

  /// Determines if a response should be cached considering metadata
  private func shouldCacheResponse(
    request: HTTPRequest,
    response: HTTPResponse,
    metadata: CacheMetadata?
  ) -> Bool {
    // If we have metadata with custom caching rules, override default behavior
    if let metadata = metadata {
      // Don't cache responses from invalidating requests
      if metadata.isInvalidating {
        return false
      }

      // Cache if it has cacheable metadata and passes basic checks
      if !metadata.tags.isEmpty || metadata.ttl != nil || metadata.customKey != nil {
        return configuration.shouldCache(request, response)
      }
    }

    return configuration.shouldCache(request, response)
  }

  /// Determines TTL considering metadata
  private func determineTTL(
    request: HTTPRequest,
    response: HTTPResponse,
    metadata: CacheMetadata?
  ) -> TimeInterval {
    // Use metadata TTL if provided
    if let metadataTTL = metadata?.ttl {
      return metadataTTL
    }

    return configuration.ttlCalculator(request, response)
  }

  private func addConditionalHeaders(to request: HTTPRequest, entry: CacheEntry) -> HTTPRequest {
    var headers = request.headers

    // Add If-None-Match header if we have an ETag
    if let etag = entry.etag {
      headers["If-None-Match"] = etag
    }

    // Add If-Modified-Since header if we have a Last-Modified date
    if let lastModified = entry.lastModified {
      headers["If-Modified-Since"] = lastModified
    }

    return HTTPRequest(
      method: request.method,
      url: request.url,
      headers: headers,
      body: request.body,
      timeout: request.timeout
    )
  }

  /// Executes a preload pattern
  private func executePreloadPattern(_ pattern: CachePreloadPattern) async {
    let requests = pattern.generateRequests()
    let results = await warmCache(requests: requests, concurrency: pattern.concurrency)

    // Log or handle results if needed
    let successCount = results.compactMap {
      if case .success = $0 { return $0 } else { return nil }
    }.count

    print("Preload pattern executed: \(successCount)/\(requests.count) requests cached")
  }

  /// Generates related requests based on current request
  private func generateRelatedRequests(
    from request: HTTPRequest,
    depth: Int
  ) -> [HTTPRequest] {
    var relatedRequests: [HTTPRequest] = []

    // Basic heuristics for generating related requests
    // This is a simplified implementation - in a real scenario you'd have
    // more sophisticated logic based on your API patterns

    let urlString = request.url.absoluteString
    let components = URLComponents(url: request.url, resolvingAgainstBaseURL: false)

    // If it's a detail endpoint, prefetch the list endpoint
    if urlString.contains("/users/") && request.method == .get {
      if let baseURL = components?.url?.deletingLastPathComponent() {
        do {
          let listRequest = try HTTPRequest {
            GET(baseURL.absoluteString)
          }
          relatedRequests.append(listRequest)
        } catch {
          // Ignore errors in generating related requests
        }
      }
    }

    // If it's a list endpoint, prefetch common detail endpoints
    if urlString.hasSuffix("/users") && request.method == .get && depth > 1 {
      // This would typically be based on your application's usage patterns
      for id in ["1", "2", "3"] {  // Common IDs
        do {
          let detailRequest = try HTTPRequest {
            GET("\(urlString)/\(id)")
          }
          relatedRequests.append(detailRequest)
        } catch {
          // Ignore errors
        }
      }
    }

    return relatedRequests
  }
}

// MARK: - Cache Warming Support Types

/// Result of a cache warming operation
public enum WarmCacheResult: Sendable {
  case success(key: String, response: HTTPResponse)
  case alreadyCached(key: String)
  case failure(request: HTTPRequest, error: any Error)

  public var isSuccess: Bool {
    switch self {
    case .success, .alreadyCached:
      return true

    case .failure:
      return false
    }
  }

  public var cacheKey: String {
    switch self {
    case .success(let key, _), .alreadyCached(let key):
      return key

    case .failure(let request, _):
      return request.url.absoluteString
    }
  }
}

/// Strategy for preloading cache entries
public enum CachePreloadStrategy: Sendable {
  case sequential
  case concurrent(maxConcurrency: Int)
  case prioritized
}

/// Pattern for cache preloading
public struct CachePreloadPattern: Sendable {
  public let name: String
  public let priority: Int
  public let concurrency: Int
  public let requestGenerator: @Sendable () -> [HTTPRequest]

  public init(
    name: String,
    priority: Int = 0,
    concurrency: Int = 2,
    requestGenerator: @escaping @Sendable () -> [HTTPRequest]
  ) {
    self.name = name
    self.priority = priority
    self.concurrency = concurrency
    self.requestGenerator = requestGenerator
  }

  public func generateRequests() -> [HTTPRequest] {
    requestGenerator()
  }
}

/// Simple async semaphore for controlling concurrency
public actor AsyncSemaphore {
  private let maxCount: Int
  private var currentCount: Int
  private var waiters: [CheckedContinuation<Void, Never>] = []

  public init(value: Int) {
    self.maxCount = value
    self.currentCount = value
  }

  public func wait() async {
    if currentCount > 0 {
      currentCount -= 1
    } else {
      await withCheckedContinuation { continuation in
        waiters.append(continuation)
      }
    }
  }

  public func signal() {
    if let waiter = waiters.first {
      waiters.removeFirst()
      waiter.resume()
    } else {
      currentCount = min(currentCount + 1, maxCount)
    }
  }
}

// MARK: - Memory Cache Storage

/// A simple in-memory cache storage implementation
public actor MemoryCacheStorage: CachingMiddleware.CacheStorage {
  private var cache: [String: CachingMiddleware.CacheEntry] = [:]
  private let maxSize: Int?

  /// Creates a new memory cache storage
  /// - Parameter maxSize: Maximum number of entries to store
  public init(maxSize: Int? = 100) {
    self.maxSize = maxSize
  }

  public func get(_ key: String) async -> CachingMiddleware.CacheEntry? {
    cache[key]
  }

  public func set(_ key: String, entry: CachingMiddleware.CacheEntry) async {
    // Remove expired entries before adding new one
    await removeExpired()

    // Check size limit
    if let maxSize = maxSize, cache.count >= maxSize {
      // Remove oldest entry (simple LRU approximation)
      let oldestKey = cache.min { lhs, rhs in
        lhs.value.cachedAt < rhs.value.cachedAt
      }?.key

      if let keyToRemove = oldestKey {
        cache.removeValue(forKey: keyToRemove)
      }
    }

    cache[key] = entry
  }

  public func remove(_ key: String) async {
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

  public func removeByTags(_ tags: [String]) async {
    // Note: Basic memory cache doesn't store tag metadata
    // This is a placeholder implementation
    // In a real scenario, you'd store tag metadata with entries
  }

  public func removeByPattern(_ pattern: String) async {
    // Simple pattern matching for cache keys
    let regex: NSRegularExpression?
    do {
      // Convert shell-style pattern to regex
      let regexPattern =
        pattern
        .replacingOccurrences(of: "*", with: ".*")
        .replacingOccurrences(of: "?", with: ".")
      regex = try NSRegularExpression(pattern: regexPattern, options: [])
    } catch {
      return  // Invalid pattern, skip
    }

    guard let regex = regex else { return }

    let keysToRemove = cache.keys.filter { key in
      let range = NSRange(location: 0, length: key.utf16.count)
      return regex.firstMatch(in: key, options: [], range: range) != nil
    }

    for key in keysToRemove {
      cache.removeValue(forKey: key)
    }
  }

  public func removeByKeys(_ keys: [String]) async {
    for key in keys {
      cache.removeValue(forKey: key)
    }
  }

  /// Returns the current cache size
  public var size: Int {
    get async { cache.count }
  }
}

// MARK: - Convenience Factory

extension CachingMiddleware {
  /// Creates a caching middleware with default memory storage
  /// - Parameters:
  ///   - client: The HTTP client to use
  ///   - ttl: Default time-to-live for cached responses
  ///   - maxCacheSize: Maximum number of entries in the cache
  /// - Returns: A configured caching middleware
  public static func withMemoryStorage(
    client: any HTTPClient,
    ttl: TimeInterval = 300.0,
    maxCacheSize: Int = 100
  ) -> CachingMiddleware {
    let storage = MemoryCacheStorage(maxSize: maxCacheSize)
    let configuration = Configuration(
      defaultTTL: ttl,
      maxCacheSize: maxCacheSize
    )

    return CachingMiddleware(
      configuration: configuration,
      storage: storage,
      client: client
    )
  }

  /// Creates a caching middleware with custom configuration
  /// - Parameters:
  ///   - client: The HTTP client to use
  ///   - customConfiguration: Custom configuration closure
  /// - Returns: A configured caching middleware
  public static func withCustomConfiguration(
    client: any HTTPClient,
    customConfiguration: (inout Configuration) -> Void
  ) -> CachingMiddleware {
    var config = Configuration()
    customConfiguration(&config)

    let storage = MemoryCacheStorage(maxSize: config.maxCacheSize)

    return CachingMiddleware(
      configuration: config,
      storage: storage,
      client: client
    )
  }
}
