import Foundation

// MARK: - Configurable Middleware Implementations

/// A retry middleware that can be configured through the DSL
struct ConfigurableRetryMiddleware: HTTPErrorMiddleware {
  let configuration: RetryConfiguration
  let session: URLSession

  init(configuration: RetryConfiguration, session: URLSession = .shared) {
    self.configuration = configuration
    self.session = session
  }

  func handleError(_ error: HTTPError, for request: HTTPRequest) async throws -> HTTPResponse {
    guard configuration.retryCondition(error).rawValue else {
      throw error
    }

    return try await performRetries(for: request, originalError: error)
  }

  private func performRetries(
    for request: HTTPRequest,
    originalError: HTTPError
  ) async throws -> HTTPResponse {
    var lastError = originalError

    for rawAttempt in 1...configuration.maxAttempts.rawValue {
      let attempt = RetryAttemptCount(rawAttempt)
      let delay = configuration.backoffStrategy.calculateDelay(
        for: attempt,
        baseDelay: configuration.delay
      )

      try await Task.sleep(nanoseconds: UInt64(delay.rawValue * 1_000_000_000))

      do {
        let response = try await performDirectRequest(request)
        return response
      } catch let error as HTTPError {
        lastError = error

        // Check if we should continue retrying
        if !configuration.retryCondition(error).rawValue {
          break
        }
      } catch {
        lastError = HTTPError(
          category: .network(.serverUnreachable),
          request: request,
          underlyingError: error
        )
      }
    }

    throw lastError
  }

  private func performDirectRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
    let urlRequest = try buildURLRequest(from: request)

    do {
      let (data, response) = try await session.data(for: urlRequest)

      guard let httpResponse = response as? HTTPURLResponse else {
        throw HTTPError(
          category: .network(.serverUnreachable),
          request: request
        )
      }

      return HTTPResponse(
        request: request,
        httpURLResponse: httpResponse,
        body: HTTPBody(data)
      )
    } catch let error as URLError {
      throw mapURLError(error, for: request)
    }
  }

  private func buildURLRequest(from httpRequest: HTTPRequest) throws -> URLRequest {
    var urlRequest = URLRequest(url: httpRequest.urlValue)
    urlRequest.httpMethod = httpRequest.method.methodValue
    urlRequest.timeoutInterval = httpRequest.timeoutInterval
    // Use session's configuration cache policy if set, otherwise default
    urlRequest.cachePolicy = session.configuration.requestCachePolicy

    // Set headers
    for (key, value) in httpRequest.headers {
      urlRequest.setValue(value.rawValue, forHTTPHeaderField: key.rawValue)
    }

    // Set body
    urlRequest.httpBody = httpRequest.bodyValue

    return urlRequest
  }

  // swiftlint:disable:next cyclomatic_complexity
  private func mapURLError(_ error: URLError, for request: HTTPRequest) -> HTTPError {
    let networkError: HTTPError.NetworkError

    switch error.code {
    case .notConnectedToInternet, .networkConnectionLost:
      networkError = .noConnection

    case .cannotFindHost, .dnsLookupFailed:
      networkError = .dnsFailure

    case .cannotConnectToHost, .timedOut:
      networkError = .serverUnreachable

    case .secureConnectionFailed, .serverCertificateUntrusted:
      networkError = .sslError

    case .cancelled:
      return HTTPError(category: .cancelled, request: request, underlyingError: error)

    default:
      networkError = .serverUnreachable
    }

    return HTTPError(
      category: .network(networkError),
      request: request,
      underlyingError: error
    )
  }
}

/// A caching middleware that can be configured through the DSL
struct ConfigurableCachingMiddleware: HTTPRequestMiddleware, HTTPResponseMiddleware {
  let configuration: CachingConfiguration

  // Create cache accessor to handle Sendable requirements
  private actor CacheActor {
    private let cache = NSCache<NSString, InternalCachedResponse>()

    func object(forKey key: NSString) -> InternalCachedResponse? {
      cache.object(forKey: key)
    }

    func setObject(_ obj: InternalCachedResponse, forKey key: NSString, cost: Int) {
      cache.setObject(obj, forKey: key, cost: cost)
    }

    func setTotalCostLimit(_ limit: Int) {
      cache.totalCostLimit = limit
    }
  }

  private let cacheActor = CacheActor()

  init(configuration: CachingConfiguration) {
    self.configuration = configuration
    configureCacheLimit()
  }

  func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
    // Check if we have a cached response
    if let cachedResponse = await getCachedResponse(for: request) {
      // Add conditional headers if appropriate
      if case .standard = configuration.policy {
        var headers = request.headers
        if let etag = cachedResponse.etag {
          headers["If-None-Match"] = etag
        }
        if let lastModified = cachedResponse.lastModified {
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
    }

    return request
  }

  func processResponse(
    _ response: HTTPResponse,
    for request: HTTPRequest
  ) async throws -> HTTPResponse {
    // Cache the response if conditions are met
    if configuration.shouldCache(request, response).rawValue {
      cacheResponse(response, for: request)
    }

    return response
  }

  private func configureCacheLimit() {
    Task {
      switch configuration.storage {
      case .memory(let size):
        await cacheActor.setTotalCostLimit(Int(size.bytes.rawValue))

      case .disk, .hybrid:
        // For simplicity, using in-memory cache only in this implementation
        // A full implementation would use URLCache or custom disk cache
        await cacheActor.setTotalCostLimit(50 * 1024 * 1024)  // 50MB default
      }
    }
  }

  private func getCachedResponse(for request: HTTPRequest) async -> InternalCachedResponse? {
    let key = cacheKey(for: request)
    return await cacheActor.object(forKey: NSString(string: key))
  }

  private func cacheResponse(_ response: HTTPResponse, for request: HTTPRequest) {
    let key = cacheKey(for: request)
    Task {
      let cachedResponse = InternalCachedResponse(
        response: response,
        cachedAt: Date(),
        etag: response.headers["ETag"],
        lastModified: response.headers["Last-Modified"]
      )

      let cost = (response.body?.count ?? BoundaryDataCount<HTTPBodyTag>(rawValue: 0)).rawValue
      await cacheActor.setObject(cachedResponse, forKey: NSString(string: key), cost: cost)
    }
  }

  private func cacheKey(for request: HTTPRequest) -> String {
    "\(request.method.rawValue):\(request.url.absoluteString)"
  }
}

/// Internal cached response wrapper for NetworkClient's caching middleware
/// Immutable cached response for internal use.
///
/// - Note: `@unchecked Sendable` justification:
///   1. Required to be a class because `NSCache` requires reference types
///   2. All properties are `let` (immutable) and themselves `Sendable`
///   3. Instance is only written once at construction, then shared read-only
///   4. Access to the cache itself is serialized through `CacheActor`
private final class InternalCachedResponse: @unchecked Sendable {
  let response: HTTPResponse
  let cachedAt: Date
  let etag: String?
  let lastModified: String?

  init(response: HTTPResponse, cachedAt: Date, etag: String?, lastModified: String?) {
    self.response = response
    self.cachedAt = cachedAt
    self.etag = etag
    self.lastModified = lastModified
  }
}
