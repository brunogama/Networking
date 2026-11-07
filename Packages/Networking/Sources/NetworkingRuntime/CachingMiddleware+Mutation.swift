import Foundation
import NetworkingCore

extension CachingMiddleware {

  public func clearCache() async {
    await invalidateStorage { await $0.removeAll() }
  }

  public func cleanExpiredEntries() async {
    await invalidateStorage { await $0.removeExpired() }
  }

  public func invalidateEntries(
    matching predicate: @Sendable (CacheKey) -> CacheInvalidationFlag
  ) async {
    await invalidateStorage { storage in
      let keys = await storage.keys().filter { predicate($0).rawValue }
      await storage.removeByKeys(keys)
    }
  }

  public func invalidateByTags(_ tags: [CacheTagName]) async {
    await invalidateStorage { await $0.removeByTags(tags) }
  }

  public func invalidateByPattern(_ pattern: CacheInvalidationPattern) async {
    await invalidateStorage { await $0.removeByPattern(pattern) }
  }

  public func invalidateByKeys(_ keys: [CacheKey]) async {
    await invalidateStorage { await $0.removeByKeys(keys) }
  }

  func invalidate(_ metadata: CacheMetadata) async {
    await invalidateStorage { storage in
      await storage.removeByTags(metadata.invalidationTags)
      await storage.removeByKeys(metadata.invalidationKeys)
      if let pattern = metadata.invalidationPattern { await storage.removeByPattern(pattern) }
    }
  }

  private func invalidateStorage(
    _ operation: @Sendable (any HTTPResponseCacheStorage) async -> Void
  ) async {
    generation = UUID()
    pendingInvalidations += 1
    await mutations.acquire()
    await operation(storage)
    await mutations.release()
    pendingInvalidations -= 1
  }

  func storeResponse(
    _ incoming: HTTPResponse,
    for request: HTTPRequest,
    generation observed: UUID
  )
    async throws -> HTTPResponse
  {
    await mutations.acquire()
    do {
      let result = try await writeResponse(incoming, for: request, generation: observed)
      await mutations.release()
      return result
    } catch {
      await mutations.release()
      throw error
    }
  }

  private func writeResponse(
    _ incoming: HTTPResponse,
    for request: HTTPRequest,
    generation observed: UUID
  )
    async throws -> HTTPResponse
  {
    try Task.checkCancellation()
    guard observed == generation else { return incoming }
    let key = cacheKey(for: request)
    let result = await revalidatedResponse(incoming, for: request, key: key)
    guard observed == generation else { return result }
    guard isCacheable(result, for: request) else {
      await storage.remove(key)
      return result
    }
    try Task.checkCancellation()
    let metadata = configuration.metadataExtractor(request)
    let ttl =
      metadata?.ttl.map { CacheMaxAge($0.rawValue) }
      ?? configuration.ttlCalculator?(request, result)
      ?? Configuration.responseTTL(from: result) ?? configuration.defaultTTL
    var entry = CacheEntry(
      response: result,
      ttl: ttl,
      etag: result.headers.caseInsensitiveValue(for: "ETag"),
      lastModified: result.headers.caseInsensitiveValue(for: "Last-Modified")
    )
    entry.tags = metadata?.tags ?? []
    await storage.set(key, entry: entry)
    if Task.isCancelled {
      await storage.remove(key)
      throw CancellationError()
    }
    return result
  }

  private func isCacheable(_ response: HTTPResponse, for request: HTTPRequest) -> Bool {
    guard Configuration.supportsVary(response) else { return false }
    return configuration.shouldCache(request, response).rawValue
  }
}
