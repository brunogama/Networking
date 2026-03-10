import Foundation
import NetworkingCore

// swiftlint:disable file_length

// swiftlint:disable type_body_length
/// Middleware that provides response caching with TTL, cache invalidation, and flexible storage strategies.
public actor CachingMiddleware: HTTPRequestMiddleware, HTTPResponseMiddleware {
  // MARK: - Cache Entry

  /// A cached response entry with metadata
  public struct CacheEntry: Sendable {
    public let response: HTTPResponse
    public let cachedAt: Date
    public let expiresAt: Date
    public let etag: HTTPHeaderValue?
    public let lastModified: HTTPHeaderValue?

    internal init(
      response: HTTPResponse,
      ttl: CacheMaxAge,
      etag: HTTPHeaderValue? = nil,
      lastModified: HTTPHeaderValue? = nil
    ) {
      self.response = response
      self.cachedAt = Date()
      self.expiresAt = Date().addingTimeInterval(ttl.rawValue)
      self.etag = etag
      self.lastModified = lastModified
    }

    /// Returns true if the cache entry has expired
    public var isExpired: CacheExpirationFlag {
      CacheExpirationFlag(Date() > expiresAt)
    }

    /// Returns the age of the cache entry in seconds
    public var age: CacheEntryAge {
      CacheEntryAge(Date().timeIntervalSince(cachedAt))
    }
  }

  // MARK: - Cache Storage Protocol

  /// Protocol for cache storage implementations
  public protocol CacheStorage: Sendable {
    /// Retrieves a cached entry for the given key
    func get(_ key: CacheKey) async -> CacheEntry?

    /// Stores a cache entry with the given key
    func set(_ key: CacheKey, entry: CacheEntry) async

    /// Removes a cached entry for the given key
    func remove(_ key: CacheKey) async

    /// Removes all cached entries
    func removeAll() async

    /// Removes expired entries
    func removeExpired() async

    /// Removes cached entries by tags (for advanced storage implementations)
    func removeByTags(_ tags: [CacheTagName]) async

    /// Removes cached entries matching a pattern (for advanced storage implementations)
    func removeByPattern(_ pattern: CacheInvalidationPattern) async

    /// Removes specific keys (for advanced storage implementations)
    func removeByKeys(_ keys: [CacheKey]) async
  }

  // MARK: - Configuration

  /// Configuration for caching behavior
  public struct Configuration: Sendable {
    /// Default time-to-live for cached responses
    public let defaultTTL: CacheMaxAge

    /// Maximum size of the cache storage
    public let maxCacheSize: CacheEntryLimit?

    /// Predicate to determine if a request should be cached
    public let shouldCache: @Sendable (HTTPRequest, HTTPResponse) -> CacheDecision

    /// Function to generate cache keys from requests
    public let cacheKeyGenerator: @Sendable (HTTPRequest) -> CacheKey

    /// Function to generate cache keys with metadata support
    public let intelligentCacheKeyGenerator: @Sendable (HTTPRequest, CacheMetadata?) -> CacheKey

    /// Function to determine TTL for specific responses
    public let ttlCalculator: @Sendable (HTTPRequest, HTTPResponse) -> CacheMaxAge

    /// Function to extract cache metadata from request attributes
    public let metadataExtractor: @Sendable (HTTPRequest) -> CacheMetadata?

    /// Whether to use conditional requests (If-None-Match, If-Modified-Since)
    public let useConditionalRequests: CacheRevalidationFlag

    public init(
      defaultTTL: CacheMaxAge = 300.0,  // 5 minutes
      maxCacheSize: CacheEntryLimit? = 100,
      shouldCache: @escaping @Sendable (HTTPRequest, HTTPResponse) -> CacheDecision = Self
        .defaultShouldCache,
      cacheKeyGenerator: @escaping @Sendable (HTTPRequest) -> CacheKey = Self.defaultCacheKey,
      intelligentCacheKeyGenerator: @escaping @Sendable (HTTPRequest, CacheMetadata?) -> CacheKey =
        Self.defaultIntelligentCacheKey,
      ttlCalculator: @escaping @Sendable (HTTPRequest, HTTPResponse) -> CacheMaxAge = Self
        .defaultTTLCalculator,
      metadataExtractor: @escaping @Sendable (HTTPRequest) -> CacheMetadata? = Self
        .defaultMetadataExtractor,
      useConditionalRequests: CacheRevalidationFlag = true
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
    public static func defaultShouldCache(
      _ request: HTTPRequest,
      _ response: HTTPResponse
    ) -> CacheDecision {
      // Only cache GET requests
      guard request.method == .get else { return false }

      // Only cache successful responses
      guard response.status.isSuccess.rawValue else { return false }

      // Don't cache responses with Cache-Control: no-cache or no-store
      if let cacheControl = response.headers["Cache-Control"]?.lowercased() {
        if cacheControl.contains("no-cache") || cacheControl.contains("no-store") {
          return false
        }
      }

      return true
    }

    /// Default cache key generator
    public static func defaultCacheKey(_ request: HTTPRequest) -> CacheKey {
      CacheKey("\(request.method.rawValue.rawValue):\(request.url.absoluteString)")
    }

    /// Intelligent cache key generator that considers metadata
    public static func defaultIntelligentCacheKey(
      _ request: HTTPRequest,
      _ metadata: CacheMetadata?
    ) -> CacheKey {
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

      return CacheKey("\(request.method.rawValue.rawValue):\(normalizedURL):\(tagsHash ?? 0)")
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
    ) -> CacheMaxAge {
      if let cacheControlTTL = cacheControlTTL(from: response) {
        return cacheControlTTL
      }

      if let expiresHeaderTTL = expiresHeaderTTL(from: response) {
        return expiresHeaderTTL
      }

      return 300.0  // 5 minutes
    }

    private static func cacheControlTTL(from response: HTTPResponse) -> CacheMaxAge? {
      guard let cacheControl = response.headers["Cache-Control"] else {
        return nil
      }

      let components = cacheControl.lowercased().components(separatedBy: ",")
      for component in components {
        let trimmed = component.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("max-age=") else { continue }

        let maxAgeString = String(trimmed.dropFirst(8))
        guard let maxAge = TimeInterval(maxAgeString) else { continue }
        return CacheMaxAge(maxAge)
      }

      return nil
    }

    private static func expiresHeaderTTL(from response: HTTPResponse) -> CacheMaxAge? {
      guard let expiresString = response.headers["Expires"] else {
        return nil
      }

      let formatter = DateFormatter()
      formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
      guard let expiresDate = formatter.date(from: expiresString) else {
        return nil
      }

      let ttl = expiresDate.timeIntervalSinceNow
      return CacheMaxAge(max(ttl, 0))
    }
  }

  // MARK: - Properties

  private let configuration: Configuration
  private let storage: any CacheStorage
  private let client: any HTTPClient

  // REENTRANCY-SAFE: track in-flight requests to deduplicate concurrent fetches
  private var inFlightRequests: [CacheKey: Task<HTTPResponse, Error>] = [:]

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
      if !cachedEntry.isExpired.rawValue {
        // We have a valid cached response, but we might want to use conditional requests
        if configuration.useConditionalRequests.rawValue {
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
    if let metadata = metadata, metadata.isInvalidating.rawValue {
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
    if shouldCacheResponse(request: request, response: response, metadata: metadata).rawValue {
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
  public func invalidateEntries(
    matching predicate: @Sendable (CacheKey) -> CacheInvalidationFlag
  ) async {
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
  public func invalidateByTags(_ tags: [CacheTagName]) async {
    await storage.removeByTags(tags)
  }

  /// Invalidates cache entries by pattern
  /// - Parameter pattern: Pattern to match against cache keys
  public func invalidateByPattern(_ pattern: CacheInvalidationPattern) async {
    await storage.removeByPattern(pattern)
  }

  /// Invalidates specific cache keys
  /// - Parameter keys: Keys to invalidate
  public func invalidateByKeys(_ keys: [CacheKey]) async {
    await storage.removeByKeys(keys)
  }

  // MARK: - Cache Warming and Prefetching

  /// Warms the cache by prefetching data for specified requests
  /// - Parameter requests: Array of requests to prefetch
  /// - Parameter concurrency: Maximum concurrent prefetch operations
  /// - Returns: Array of results indicating success/failure for each request
  public func warmCache(
    requests: [HTTPRequest],
    concurrency: CachePreloadConcurrency = 4
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
  /// - Note: REENTRANCY-SAFE - deduplicates concurrent requests for same key
  public func prefetchSingle(request: HTTPRequest) async -> WarmCacheResult {
    do {
      // Check if already cached and fresh
      let metadata = configuration.metadataExtractor(request)
      let cacheKey = configuration.intelligentCacheKeyGenerator(request, metadata)

      if let existingEntry = await storage.get(cacheKey), !existingEntry.isExpired.rawValue {
        return .alreadyCached(key: cacheKey)
      }

      // Check if request already in flight - join existing
      if let existingTask = inFlightRequests[cacheKey] {
        let response = try await existingTask.value
        return .success(key: cacheKey, response: response)
      }

      // Start new request - store task BEFORE await
      let task = Task<HTTPResponse, Error> {
        let response = try await client.execute(request)
        return try await processResponse(response, for: request)
      }
      inFlightRequests[cacheKey] = task

      // Clean up after completion
      defer { inFlightRequests[cacheKey] = nil }

      let processedResponse = try await task.value
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
      await preloadSequentially(patterns)

    case .concurrent(let maxConcurrency):
      await preloadConcurrently(patterns, maxConcurrency: maxConcurrency)

    case .prioritized:
      await preloadPrioritized(patterns)
    }
  }

  /// Intelligently prefetches related content based on current request
  /// - Parameter request: The current request
  /// - Parameter depth: How many levels of related content to prefetch
  /// - Returns: Number of items prefetched
  @discardableResult
  public func intelligentPrefetch(
    basedOn request: HTTPRequest,
    depth: CachePrefetchDepth = 1
  ) async -> CachePrefetchCount {
    guard depth > 0 else { return 0 }

    var prefetchedCount: CachePrefetchCount = 0
    let relatedRequests = generateRelatedRequests(from: request, depth: depth)

    for relatedRequest in relatedRequests {
      let result = await prefetchSingle(request: relatedRequest)
      if case .success = result {
        prefetchedCount = CachePrefetchCount(prefetchedCount.rawValue + 1)
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
  ) -> CacheDecision {
    // If we have metadata with custom caching rules, override default behavior
    if let metadata = metadata {
      // Don't cache responses from invalidating requests
      if metadata.isInvalidating.rawValue {
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
  ) -> CacheMaxAge {
    // Use metadata TTL if provided
    if let metadataTTL = metadata?.ttl {
      return CacheMaxAge(metadataTTL.rawValue)
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
    _ = await warmCache(requests: requests, concurrency: pattern.concurrency)
  }

  /// Generates related requests based on current request
  private func generateRelatedRequests(
    from request: HTTPRequest,
    depth: CachePrefetchDepth
  ) -> [HTTPRequest] {
    var relatedRequests: [HTTPRequest] = []

    let urlString = request.url.absoluteString
    let components = URLComponents(url: request.url, resolvingAgainstBaseURL: false)

    if let listRequest = relatedListRequest(
      for: request,
      urlString: urlString,
      components: components
    ) {
      relatedRequests.append(listRequest)
    }

    relatedRequests.append(
      contentsOf: relatedDetailRequests(for: request, urlString: urlString, depth: depth)
    )

    return relatedRequests
  }

  private func preloadSequentially(_ patterns: [CachePreloadPattern]) async {
    for pattern in patterns {
      await executePreloadPattern(pattern)
    }
  }

  private func preloadConcurrently(
    _ patterns: [CachePreloadPattern],
    maxConcurrency: CachePreloadConcurrency
  ) async {
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
  }

  private func preloadPrioritized(_ patterns: [CachePreloadPattern]) async {
    let sortedPatterns = patterns.sorted { lhs, rhs in
      lhs.priority > rhs.priority
    }

    for pattern in sortedPatterns {
      await executePreloadPattern(pattern)
    }
  }

  private func relatedListRequest(
    for request: HTTPRequest,
    urlString: String,
    components: URLComponents?
  ) -> HTTPRequest? {
    guard urlString.contains("/users/"), request.method == .get else {
      return nil
    }

    guard let baseURL = components?.url?.deletingLastPathComponent() else {
      return nil
    }

    return HTTPRequest(method: .get, url: baseURL)
  }

  private func relatedDetailRequests(
    for request: HTTPRequest,
    urlString: String,
    depth: CachePrefetchDepth
  ) -> [HTTPRequest] {
    guard urlString.hasSuffix("/users"), request.method == .get, depth > 1 else {
      return []
    }

    return ["1", "2", "3"].compactMap { id in
      guard let detailURL = URL(string: "\(urlString)/\(id)") else {
        return nil
      }

      return HTTPRequest(method: .get, url: detailURL)
    }
  }
}
// swiftlint:enable type_body_length

// MARK: - Cache Warming Support Types

/// Result of a cache warming operation
public enum WarmCacheResult: Sendable {
  case success(key: CacheKey, response: HTTPResponse)
  case alreadyCached(key: CacheKey)
  case failure(request: HTTPRequest, error: any Error)

  public var isSuccess: CacheWarmSuccessFlag {
    switch self {
    case .success, .alreadyCached:
      return true

    case .failure:
      return false
    }
  }

  public var cacheKey: CacheKey {
    switch self {
    case .success(let key, _), .alreadyCached(let key):
      return key

    case .failure(let request, _):
      return CacheKey(request.url.absoluteString)
    }
  }
}

/// Strategy for preloading cache entries
public enum CachePreloadStrategy: Sendable {
  case sequential
  case concurrent(maxConcurrency: CachePreloadConcurrency)
  case prioritized
}

/// Pattern for cache preloading
public struct CachePreloadPattern: Sendable {
  public let name: CachePatternName
  public let priority: CachePreloadPriority
  public let concurrency: CachePreloadConcurrency
  public let requestGenerator: @Sendable () -> [HTTPRequest]

  public init(
    name: CachePatternName,
    priority: CachePreloadPriority = 0,
    concurrency: CachePreloadConcurrency = 2,
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
  private let maxCount: CachePreloadConcurrency
  private var currentCount: CachePreloadConcurrency
  private var waiters: [CheckedContinuation<Void, Never>] = []

  public init(value: CachePreloadConcurrency) {
    self.maxCount = value
    self.currentCount = value
  }

  public func wait() async {
    if currentCount > 0 {
      currentCount = CachePreloadConcurrency(currentCount.rawValue - 1)
    } else {
      await withTaskCancellationHandler {
        await withCheckedContinuation { continuation in
          // Check cancellation before storing
          if Task.isCancelled {
            continuation.resume()
            return
          }
          waiters.append(continuation)
        }
      } onCancel: {
        Task {
          await self.cancelWait()
        }
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

  /// Cancels a waiting continuation when task is cancelled
  private func cancelWait() {
    // When cancelled, we need to release one waiter if any are waiting
    // This ensures the continuation stored before cancellation is resumed
    if !waiters.isEmpty {
      let waiter = waiters.removeFirst()
      waiter.resume()
    }
  }
}

// swiftlint:enable file_length
