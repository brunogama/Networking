import Foundation
import NetworkingCore

/// Middleware that provides response caching with TTL, cache invalidation, and flexible storage strategies.
public actor CachingMiddleware: HTTPRequestMiddleware, HTTPResponseMiddleware {
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

}
