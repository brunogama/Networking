import Foundation
import NetworkingCore

extension CachingMiddleware {
  func addConditionalHeaders(to request: HTTPRequest, entry: CacheEntry) -> HTTPRequest {
    var headers = request.headers
    if let etag = entry.etag { headers["If-None-Match"] = etag }
    if let modified = entry.lastModified { headers["If-Modified-Since"] = modified }
    return HTTPRequest(
      method: request.method,
      url: request.url,
      headers: headers,
      body: request.body,
      timeout: request.timeoutOverride,
      id: request.id
    )
  }

  func revalidatedResponse(
    _ incoming: HTTPResponse,
    for request: HTTPRequest,
    key: CacheKey
  )
    async -> HTTPResponse
  {
    guard incoming.status.rawValue == 304,
      let entry = await storage.getForRevalidation(key)
    else { return incoming }
    var headers = entry.response.headers.rawValue
    for (name, value) in incoming.headers {
      headers = headers.filter { $0.key.caseInsensitiveCompare(name.rawValue) != .orderedSame }
      headers[name.rawValue] = value.rawValue
    }
    return HTTPResponse(
      request: request,
      status: entry.response.status,
      headers: HTTPHeaders(rawValue: headers),
      body: entry.response.body
    )
  }

  /// Fetches explicitly requested content in the caller's task; concurrent callers remain independent.
  ///
  /// Cancellation or an intervening invalidation prevents this operation from publishing an entry.
  public func prefetchSingle(request: HTTPRequest) async -> WarmCacheResult {
    let observed = generation
    let key = cacheKey(for: request)
    do {
      try Task.checkCancellation()
      if await cachedResponse(for: request) != nil { return .alreadyCached(key: key) }
      let response = try await client.execute(request)
      try Task.checkCancellation()
      guard observed == generation else { throw CancellationError() }
      let result = try await storeResponse(response, for: request, generation: observed)
      try Task.checkCancellation()
      guard observed == generation else { throw CancellationError() }
      return .success(key: key, response: result)
    } catch { return .failure(request: request, error: error) }
  }

  /// Prefetches only the supplied requests with bounded structured concurrency.
  ///
  /// Results retain input order; cancellation propagates to child requests and all children are joined.
  public func warmCache(
    requests: [HTTPRequest],
    concurrency: CachePreloadConcurrency = 4
  )
    async -> [WarmCacheResult]
  {
    let limit = min(max(1, concurrency.rawValue), requests.count)
    return await withTaskGroup(of: (Int, WarmCacheResult).self) { group in
      for index in 0..<limit {
        group.addTask { (index, await self.prefetchSingle(request: requests[index])) }
      }
      var next = limit
      var results = [WarmCacheResult?](repeating: nil, count: requests.count)
      for await (index, result) in group {
        results[index] = result
        if next < requests.count {
          let scheduled = next
          next += 1
          group.addTask { (scheduled, await self.prefetchSingle(request: requests[scheduled])) }
        }
      }
      return results.compactMap { $0 }
    }
  }
}
