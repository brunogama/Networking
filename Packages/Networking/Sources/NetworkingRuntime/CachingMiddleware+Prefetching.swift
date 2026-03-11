import Foundation
import NetworkingCore

extension CachingMiddleware {
  func addConditionalHeaders(to request: HTTPRequest, entry: CacheEntry) -> HTTPRequest {
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
  func executePreloadPattern(_ pattern: CachePreloadPattern) async {
    let requests = pattern.generateRequests()
    _ = await warmCache(requests: requests, concurrency: pattern.concurrency)
  }

  /// Generates related requests based on current request
  func generateRelatedRequests(
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

  func preloadSequentially(_ patterns: [CachePreloadPattern]) async {
    for pattern in patterns {
      await executePreloadPattern(pattern)
    }
  }

  func preloadConcurrently(
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

  func preloadPrioritized(_ patterns: [CachePreloadPattern]) async {
    let sortedPatterns = patterns.sorted { lhs, rhs in
      lhs.priority > rhs.priority
    }

    for pattern in sortedPatterns {
      await executePreloadPattern(pattern)
    }
  }

  func relatedListRequest(
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

  func relatedDetailRequests(
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
