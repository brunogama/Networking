import Foundation
import NetworkingCore

/// Optional response caching with caller-owned prefetch and serialized invalidation.
public actor CachingMiddleware: CachedResponseProviding, HTTPRequestMiddleware,
  HTTPResponseMiddleware
{
  let configuration: Configuration
  let storage: any HTTPResponseCacheStorage
  let client: any HTTPClient
  let mutations = CacheMutationGate()
  var generation = UUID()
  var pendingInvalidations = 0

  /// Creates a cache using the supplied storage and client for explicit prefetch requests.
  public init(
    configuration: Configuration,
    storage: any HTTPResponseCacheStorage,
    client: any HTTPClient
  ) {
    self.configuration = configuration
    self.storage = storage
    self.client = client
  }

  /// Adds validators to stale GET requests without changing their logical identity.
  public func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
    guard request.method == .get, configuration.useConditionalRequests.rawValue else {
      return request
    }
    let observed = generation
    let entry = await storage.getForRevalidation(cacheKey(for: request))
    guard observed == generation, pendingInvalidations == 0, let entry,
      entry.isExpired.rawValue
    else { return request }
    return addConditionalHeaders(to: request, entry: entry)
  }

  package func cachedResponse(for request: HTTPRequest) async -> HTTPResponse? {
    guard request.method == .get, pendingInvalidations == 0 else { return nil }
    let observed = generation
    let key = cacheKey(for: request)
    let retained = await storage.getForRevalidation(key)
    guard observed == generation, pendingInvalidations == 0, let retained,
      !retained.isExpired.rawValue
    else { return nil }
    let accessed = await storage.get(key)
    guard observed == generation, pendingInvalidations == 0, let accessed,
      !accessed.isExpired.rawValue
    else { return nil }
    return response(accessed.response, for: request)
  }

  /// Stores cacheable responses or resolves 304 revalidation using retained content.
  public func processResponse(
    _ response: HTTPResponse,
    for request: HTTPRequest
  )
    async throws -> HTTPResponse
  {
    let metadata = configuration.metadataExtractor(request)
    if let metadata, metadata.isInvalidating.rawValue {
      await invalidate(metadata)
      return response
    }
    return try await storeResponse(response, for: request, generation: generation)
  }

  /// Returns a fresh cache entry for inspection.
  public func getCachedEntry(for request: HTTPRequest) async -> CacheEntry? {
    guard pendingInvalidations == 0 else { return nil }
    let observed = generation
    let result = await storage.get(cacheKey(for: request))
    guard observed == generation, pendingInvalidations == 0 else { return nil }
    return result
  }

  func cacheKey(for request: HTTPRequest) -> CacheKey {
    let metadata = configuration.metadataExtractor(request)
    let base = metadata?.customKey ?? configuration.cacheKeyGenerator(request)
    return Configuration.partitionedKey(base, request: request, tags: metadata?.tags ?? [])
  }

  func response(_ cached: HTTPResponse, for request: HTTPRequest) -> HTTPResponse {
    HTTPResponse(
      request: request,
      status: cached.status,
      headers: cached.headers,
      body: cached.body
    )
  }
}
