import Foundation

/// Modern HTTP client implementation using URLSession and structured concurrency.
///
/// `NetworkClient` is the primary implementation of ``HTTPClient`` that provides a comprehensive
/// networking solution built on top of URLSession. It supports a middleware pipeline for request
/// and response processing, automatic error recovery, and is fully compatible with Swift's
/// structured concurrency model.
///
/// ## Usage
///
/// ### Basic Client Creation
///
/// ```swift
/// let client = NetworkClient()
/// let response = try await client.execute(request)
/// ```
///
/// ### Client with Middleware
///
/// ```swift
/// let client = NetworkClient(
///     requestMiddlewares: [AuthenticationMiddleware()],
///     responseMiddlewares: [CachingMiddleware()],
///     errorMiddlewares: [RetryMiddleware()]
/// )
/// ```
///
/// ### Configuration-Based Client
///
/// ```swift
/// let client = NetworkClient {
///     BaseURL("https://api.example.com")
///     EnableLogging()
///     EnableRetry()
///     Authentication {
///         BearerToken(tokenProvider)
///     }
/// }
/// ```
///
/// ## Architecture
///
/// The client processes requests through a three-stage middleware pipeline:
///
/// 1. **Request Middleware**: Modifies requests before execution (authentication, logging, etc.)
/// 2. **Network Execution**: Performs the actual HTTP request using URLSession
/// 3. **Response Middleware**: Processes responses after execution (caching, validation, etc.)
/// 4. **Error Middleware**: Handles errors and provides recovery strategies (retry, fallback, etc.)
///
/// ## Thread Safety
///
/// `NetworkClient` is fully thread-safe and `Sendable`. All middleware operations are executed
/// in a controlled manner that ensures safe concurrent access. The client can be safely shared
/// across multiple tasks and actors.
///
/// ## Related Documentation
///
/// - <doc:Client-Configuration>: Complete configuration guide
/// - <doc:Middleware-System>: Creating custom middleware
/// - <doc:Core-Networking>: Understanding HTTP primitives
public final class NetworkClient: HTTPClient {
  // MARK: - Properties

  private let session: URLSession
  private let requestMiddlewares: [any HTTPRequestMiddleware]
  private let responseMiddlewares: [any HTTPResponseMiddleware]
  private let errorMiddlewares: [any HTTPErrorMiddleware]

  // MARK: - Initialization

  public init(
    session: URLSession = .shared,
    requestMiddlewares: [any HTTPRequestMiddleware] = [],
    responseMiddlewares: [any HTTPResponseMiddleware] = [],
    errorMiddlewares: [any HTTPErrorMiddleware] = []
  ) {
    self.session = session
    self.requestMiddlewares = requestMiddlewares
    self.responseMiddlewares = responseMiddlewares
    self.errorMiddlewares = errorMiddlewares
  }

  // MARK: - HTTPClient

  public func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
    do {
      // Apply request middlewares
      let processedRequest = try await applyRequestMiddlewares(request)

      // Execute the request
      let response = try await performRequest(processedRequest)
      // Apply response middlewares
      return try await applyResponseMiddlewares(response, for: processedRequest)
    } catch let error as HTTPError {
      // Try to handle error with middlewares
      return try await handleErrorWithMiddlewares(error, for: request)
    } catch {
      // Convert other errors to HTTPError
      let httpError = HTTPError(
        category: .network(.serverUnreachable),
        request: request,
        underlyingError: error
      )
      return try await handleErrorWithMiddlewares(httpError, for: request)
    }
  }

  // MARK: - Private Methods

  private func applyRequestMiddlewares(_ request: HTTPRequest) async throws -> HTTPRequest {
    var currentRequest = request
    for middleware in requestMiddlewares {
      currentRequest = try await middleware.modifyRequest(currentRequest)
    }
    return currentRequest
  }

  private func applyResponseMiddlewares(
    _ response: HTTPResponse,
    for request: HTTPRequest
  ) async throws -> HTTPResponse {
    var currentResponse = response
    for middleware in responseMiddlewares {
      currentResponse = try await middleware.processResponse(currentResponse, for: request)
    }
    return currentResponse
  }
  private func handleErrorWithMiddlewares(
    _ error: HTTPError,
    for request: HTTPRequest
  ) async throws -> HTTPResponse {
    var currentError = error
    for middleware in errorMiddlewares {
      do {
        return try await middleware.handleError(currentError, for: request)
      } catch let newError as HTTPError {
        currentError = newError
      } catch {
        currentError = HTTPError(
          category: .network(.serverUnreachable),
          request: request,
          underlyingError: error
        )
      }
    }
    throw currentError
  }

  private func performRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
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
        body: data
      )
    } catch let error as URLError {
      throw mapURLError(error, for: request)
    }
  }
  private func buildURLRequest(from httpRequest: HTTPRequest) throws -> URLRequest {
    var urlRequest = URLRequest(url: httpRequest.url)
    urlRequest.httpMethod = httpRequest.method.rawValue
    urlRequest.timeoutInterval = httpRequest.timeout

    // Set headers
    for (key, value) in httpRequest.headers {
      urlRequest.setValue(value, forHTTPHeaderField: key)
    }

    // Set body
    urlRequest.httpBody = httpRequest.body

    return urlRequest
  }

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

// MARK: - NetworkClient Builder Extension

extension NetworkClient {
  /// Creates a NetworkClient using the configuration builder pattern.
  ///
  /// This convenience initializer allows you to configure a NetworkClient using a declarative,
  /// Swift DSL syntax. The configuration is processed to set up middleware chains, security
  /// settings, and other client behaviors.
  ///
  /// - Parameter content: A closure that returns configuration components using the
  ///   ``NetworkClientBuilder`` result builder syntax
  /// - Returns: A fully configured NetworkClient instance
  ///
  /// ## Example Usage
  ///
  /// ```swift
  /// let client = NetworkClient {
  ///     BaseURL("https://api.example.com")
  ///     DefaultTimeout(30.0)
  ///
  ///     Authentication {
  ///         BearerToken(tokenProvider)
  ///         AuthRefreshStrategy(.automatic)
  ///     }
  ///
  ///     Retry {
  ///         MaxAttempts(3)
  ///         BackoffStrategy(.exponential)
  ///     }
  ///
  ///     Caching {
  ///         Policy(.standard)
  ///         Storage(.memory(size: .MB(50)))
  ///     }
  ///
  ///     EnableLogging()
  ///     EnableSecurity {
  ///         SSLPinning(.certificates(certificates))
  ///     }
  /// }
  /// ```
  ///
  /// ## Configuration Processing
  ///
  /// The configuration is processed in the following order:
  /// 1. Base configuration (URL, headers, timeouts)
  /// 2. Security configuration and session setup
  /// 3. Middleware chain construction
  /// 4. Validation of the complete configuration
  ///
  /// - Note: This initializer validates the configuration and will create optimized
  ///   middleware chains based on the provided components.
  public convenience init(@NetworkClientBuilder _ content: () -> [any ConfigurationComponent]) {
    var config = NetworkClientBuilder.Configuration()
    let components = content()

    for component in components {
      component.apply(to: &config)
    }

    Self.validateConfiguration(&config)
    let middlewares = Self.configureMiddlewareChain(from: config)

    self.init(
      session: config.session,
      requestMiddlewares: middlewares.request,
      responseMiddlewares: middlewares.response,
      errorMiddlewares: middlewares.error
    )
  }

  /// Validates and applies security configuration to session
  private static func validateConfiguration(_ config: inout NetworkClientBuilder.Configuration) {
    // Apply security configuration to session if configured
    if let securityConfig = config.securityConfiguration {
      // Create a secure URLSession with the security configuration
      if let sessionConfig = config.sessionConfiguration {
        config.session = sessionConfig.createURLSession(securityConfiguration: securityConfig)
      } else {
        // Use default session configuration with security
        let sessionConfig = SessionConfiguration()
        config.session = sessionConfig.createURLSession(securityConfiguration: securityConfig)
      }
    }
  }

  /// Configures the complete middleware chain from configuration
  private static func configureMiddlewareChain(
    from config: NetworkClientBuilder.Configuration
  ) -> (
    request: [any HTTPRequestMiddleware], response: [any HTTPResponseMiddleware],
    error: [any HTTPErrorMiddleware]
  ) {
    var requestMiddlewares = config.requestMiddlewares
    var responseMiddlewares = config.responseMiddlewares
    var errorMiddlewares = config.errorMiddlewares

    // Apply base URL and default headers as request middleware if configured
    if let baseURL = config.baseURL {
      let baseURLMiddleware = BaseURLMiddleware(baseURL: baseURL)
      requestMiddlewares.insert(baseURLMiddleware, at: 0)
    }

    if !config.defaultHeaders.isEmpty {
      let headersMiddleware = DefaultHeadersMiddleware(headers: config.defaultHeaders)
      requestMiddlewares.insert(headersMiddleware, at: 0)
    }

    // Create a temporary client instance to pass to middlewares
    let temporaryClient = NetworkClient(
      session: config.session,
      requestMiddlewares: [],
      responseMiddlewares: [],
      errorMiddlewares: []
    )

    // Apply authentication configuration
    if let authConfig = config.authenticationConfiguration {
      let authMiddleware = Self.createAuthenticationMiddleware(
        from: authConfig,
        client: temporaryClient
      )
      requestMiddlewares.append(authMiddleware)
      errorMiddlewares.append(authMiddleware)
    }

    // Apply retry configuration
    if let retryConfig = config.retryConfiguration {
      let retryMiddleware = ConfigurableRetryMiddleware(
        configuration: retryConfig,
        session: config.session
      )
      errorMiddlewares.append(retryMiddleware)
    }

    // Apply caching configuration
    if let cachingConfig = config.cachingConfiguration {
      let cachingMiddleware = ConfigurableCachingMiddleware(
        configuration: cachingConfig
      )
      requestMiddlewares.append(cachingMiddleware)
      responseMiddlewares.append(cachingMiddleware)
    }

    return (request: requestMiddlewares, response: responseMiddlewares, error: errorMiddlewares)
  }

  /// Creates an authentication middleware from configuration.
  private static func createAuthenticationMiddleware(
    from config: AuthenticationConfiguration,
    client: any HTTPClient
  ) -> AuthenticationMiddleware {
    let tokenProvider: any AuthenticationMiddleware.TokenProvider

    switch config.strategy {
    case .bearerToken(let provider):
      tokenProvider = BearerTokenProviderWrapper(
        provider: provider,
        refreshStrategy: config.refreshStrategy
      )

    case .basicAuth(let username, let password):
      tokenProvider = BasicAuthTokenProvider(username: username, password: password)

    case .custom(let customProvider):
      tokenProvider = CustomAuthTokenProvider(customProvider: customProvider)
    }

    let middlewareConfig = AuthenticationMiddleware.Configuration(
      authorizationHeaderName: config.headerName,
      tokenPrefix: config.strategy.tokenPrefix,
      maxRefreshAttempts: 1,
      shouldAuthenticate: config.shouldAuthenticate
    )

    return AuthenticationMiddleware(
      configuration: middlewareConfig,
      tokenProvider: tokenProvider,
      client: client
    )
  }
}

/// Middleware that adds a base URL to requests that don't have a complete URL.
private struct BaseURLMiddleware: HTTPRequestMiddleware {
  private let baseURL: URL

  init(baseURL: URL) {
    self.baseURL = baseURL
  }

  func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
    // If the request URL is relative, combine it with the base URL
    if request.url.host == nil {
      let combinedURL = baseURL.appendingPathComponent(request.url.path)
      return HTTPRequest(
        method: request.method,
        url: combinedURL,
        headers: request.headers,
        body: request.body,
        timeout: request.timeout
      )
    }
    return request
  }
}

/// Middleware that adds default headers to all requests.
private struct DefaultHeadersMiddleware: HTTPRequestMiddleware {
  private let headers: [String: String]

  init(headers: [String: String]) {
    self.headers = headers
  }

  func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
    var combinedHeaders = headers
    // Request headers take precedence over default headers
    for (key, value) in request.headers {
      combinedHeaders[key] = value
    }

    return HTTPRequest(
      method: request.method,
      url: request.url,
      headers: combinedHeaders,
      body: request.body,
      timeout: request.timeout
    )
  }
}

// MARK: - Authentication Strategy Extensions

extension AuthenticationStrategy {
  var tokenPrefix: String {
    switch self {
    case .bearerToken:
      return "Bearer "

    case .basicAuth:
      return "Basic "

    case .custom:
      return ""
    }
  }
}

// MARK: - Token Provider Wrappers

/// Wrapper to adapt BearerTokenProvider to AuthenticationMiddleware.TokenProvider
private struct BearerTokenProviderWrapper: AuthenticationMiddleware.TokenProvider {
  let provider: any BearerTokenProvider
  let refreshStrategy: AuthRefreshStrategy

  func getCurrentToken() async throws -> String? {
    try await provider.getCurrentToken()
  }

  func refreshToken() async throws -> String {
    switch refreshStrategy {
    case .none:
      throw HTTPError(category: .configuration("Token refresh is disabled"))

    case .automatic:
      return try await provider.refreshToken()

    case .manual(let handler):
      return try await handler()
    }
  }

  func shouldRefreshToken(for error: HTTPError) async -> Bool {
    // If refresh strategy is .none, don't refresh
    if case .none = refreshStrategy {
      return false
    }

    switch error.category {
    case .http(let status) where status.rawValue == 401:
      return true

    default:
      return false
    }
  }
}

/// Token provider for basic authentication
private struct BasicAuthTokenProvider: AuthenticationMiddleware.TokenProvider {
  let username: String
  let password: String

  func getCurrentToken() async throws -> String? {
    let credentials = "\(username):\(password)"
    guard let data = credentials.data(using: .utf8) else {
      throw HTTPError(category: .configuration("Invalid basic auth credentials"))
    }
    return data.base64EncodedString()
  }

  func refreshToken() async throws -> String {
    // Basic auth doesn't need refresh, return current token
    try await getCurrentToken() ?? ""
  }

  func shouldRefreshToken(for error: HTTPError) async -> Bool {
    // Basic auth typically doesn't require refresh
    false
  }
}

/// Token provider for custom authentication
private struct CustomAuthTokenProvider: AuthenticationMiddleware.TokenProvider {
  let customProvider: any CustomAuthProvider

  func getCurrentToken() async throws -> String? {
    // Custom providers handle token extraction differently
    nil
  }

  func refreshToken() async throws -> String {
    throw HTTPError(category: .configuration("Custom auth provider doesn't support token refresh"))
  }

  func shouldRefreshToken(for error: HTTPError) async -> Bool {
    false
  }
}

// MARK: - Configurable Middleware Implementations

/// A retry middleware that can be configured through the DSL
private struct ConfigurableRetryMiddleware: HTTPErrorMiddleware {
  let configuration: RetryConfiguration
  let session: URLSession

  init(configuration: RetryConfiguration, session: URLSession = .shared) {
    self.configuration = configuration
    self.session = session
  }

  func handleError(_ error: HTTPError, for request: HTTPRequest) async throws -> HTTPResponse {
    guard configuration.retryCondition(error) else {
      throw error
    }

    return try await performRetries(for: request, originalError: error)
  }

  private func performRetries(
    for request: HTTPRequest,
    originalError: HTTPError
  ) async throws -> HTTPResponse {
    var lastError = originalError

    for attempt in 1...configuration.maxAttempts {
      let delay = configuration.backoffStrategy.calculateDelay(
        for: attempt,
        baseDelay: configuration.delay
      )

      try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

      do {
        let response = try await performDirectRequest(request)
        return response
      } catch let error as HTTPError {
        lastError = error

        // Check if we should continue retrying
        if !configuration.retryCondition(error) {
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
        body: data
      )
    } catch let error as URLError {
      throw mapURLError(error, for: request)
    }
  }

  private func buildURLRequest(from httpRequest: HTTPRequest) throws -> URLRequest {
    var urlRequest = URLRequest(url: httpRequest.url)
    urlRequest.httpMethod = httpRequest.method.rawValue
    urlRequest.timeoutInterval = httpRequest.timeout

    // Set headers
    for (key, value) in httpRequest.headers {
      urlRequest.setValue(value, forHTTPHeaderField: key)
    }

    // Set body
    urlRequest.httpBody = httpRequest.body

    return urlRequest
  }

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
private struct ConfigurableCachingMiddleware: HTTPRequestMiddleware, HTTPResponseMiddleware {
  let configuration: CachingConfiguration

  // Create cache accessor to handle Sendable requirements
  private actor CacheActor {
    private let cache = NSCache<NSString, CachedResponse>()

    func object(forKey key: NSString) -> CachedResponse? {
      cache.object(forKey: key)
    }

    func setObject(_ obj: CachedResponse, forKey key: NSString, cost: Int) {
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
    if configuration.shouldCache(request, response) {
      cacheResponse(response, for: request)
    }

    return response
  }

  private func configureCacheLimit() {
    Task {
      switch configuration.storage {
      case .memory(let size):
        await cacheActor.setTotalCostLimit(Int(size.bytes))

      case .disk, .hybrid:
        // For simplicity, using in-memory cache only in this implementation
        // A full implementation would use URLCache or custom disk cache
        await cacheActor.setTotalCostLimit(50 * 1024 * 1024)  // 50MB default
      }
    }
  }

  private func getCachedResponse(for request: HTTPRequest) async -> CachedResponse? {
    let key = cacheKey(for: request)
    return await cacheActor.object(forKey: NSString(string: key))
  }

  private func cacheResponse(_ response: HTTPResponse, for request: HTTPRequest) {
    let key = cacheKey(for: request)
    Task {
      let cachedResponse = CachedResponse(
        response: response,
        cachedAt: Date(),
        etag: response.headers["ETag"],
        lastModified: response.headers["Last-Modified"]
      )

      let cost = response.body?.count ?? 0
      await cacheActor.setObject(cachedResponse, forKey: NSString(string: key), cost: cost)
    }
  }

  private func cacheKey(for request: HTTPRequest) -> String {
    "\(request.method.rawValue):\(request.url.absoluteString)"
  }
}

/// Cached response wrapper
private final class CachedResponse: @unchecked Sendable {
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
