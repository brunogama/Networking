// swiftlint:disable file_length
import Foundation

// MARK: - NetworkClient Builder Extension

extension NetworkClient {
  private struct MiddlewareChain {
    var request: [any HTTPRequestMiddleware]
    var response: [any HTTPResponseMiddleware]
    var error: [any HTTPErrorMiddleware]
  }

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
  public convenience init(
    @NetworkClientBuilder _ content: () throws -> [any ConfigurationComponent]
  ) throws {
    var config = NetworkClientBuilder.Configuration()
    let components = try content()

    for component in components {
      component.apply(to: &config)
    }

    try Self.validateConfiguration(&config)
    let middlewares = try Self.configureMiddlewareChain(from: config)

    self.init(
      session: config.session,
      requestMiddlewares: middlewares.request,
      responseMiddlewares: middlewares.response,
      errorMiddlewares: middlewares.error,
      defaultTimeout: config.timeout,
      trafficRecorder: config.trafficRecorder
    )
  }

  /// Creates a NetworkClient from an array of configuration components.
  ///
  /// This convenience initializer allows you to configure a NetworkClient using an array of
  /// configuration components. This is useful for conditional configuration where you need
  /// to build the components array programmatically.
  ///
  /// - Parameter components: An array of configuration components
  /// - Returns: A fully configured NetworkClient instance
  /// - Throws: Configuration errors if the setup is invalid
  public convenience init(components: [any ConfigurationComponent]) throws {
    var config = NetworkClientBuilder.Configuration()

    for component in components {
      component.apply(to: &config)
    }

    try Self.validateConfiguration(&config)
    let middlewares = try Self.configureMiddlewareChain(from: config)

    self.init(
      session: config.session,
      requestMiddlewares: middlewares.request,
      responseMiddlewares: middlewares.response,
      errorMiddlewares: middlewares.error,
      defaultTimeout: config.timeout,
      trafficRecorder: config.trafficRecorder
    )
  }

  /// Validates and applies security configuration to session
  private static func validateConfiguration(
    _ config: inout NetworkClientBuilder.Configuration
  ) throws {
    if config.hasCustomSession, config.sessionConfiguration != nil {
      throw HTTPError(
        category: .configuration("CustomSession cannot be combined with Session settings")
      )
    }

    // Apply security configuration to session if configured
    if let securityConfig = config.securityConfiguration {
      guard !config.hasCustomSession else {
        throw HTTPError(
          category: .configuration(
            "CustomSession cannot be combined with EnableSecurity, which requires its own delegate"
          )
        )
      }
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

  // Configures the complete middleware chain from configuration.
  // swiftlint:disable:next cyclomatic_complexity function_body_length
  private static func configureMiddlewareChain(
    from config: NetworkClientBuilder.Configuration
  ) throws -> MiddlewareChain {
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
      errorMiddlewares: [],
      defaultTimeout: config.timeout,
      trafficRecorder: config.trafficRecorder
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
        client: temporaryClient
      )
      errorMiddlewares.append(retryMiddleware)
    }

    if let retryConfig = config.legacyRetryConfiguration {
      errorMiddlewares.append(
        RetryMiddleware(configuration: retryConfig, client: temporaryClient)
      )
    }

    // Apply caching configuration
    if let cachingConfig = config.cachingConfiguration,
      let cachingMiddleware = try Self.createCachingMiddleware(
        from: cachingConfig,
        client: temporaryClient
      )
    {
      requestMiddlewares.append(cachingMiddleware)
      responseMiddlewares.append(cachingMiddleware)
    }

    return MiddlewareChain(
      request: requestMiddlewares,
      response: responseMiddlewares,
      error: errorMiddlewares
    )
  }

  private static func createCachingMiddleware(
    from configuration: CachingConfiguration,
    client: any HTTPClient
  ) throws -> CachingMiddleware? {
    if case .none = configuration.policy {
      return nil
    }

    let storage = try Self.createCacheStorage(from: configuration.storage)
    let middlewareConfiguration = Self.createCachingConfiguration(from: configuration)
    return CachingMiddleware(
      configuration: middlewareConfiguration,
      storage: storage,
      client: client
    )
  }

  private static func createCachingConfiguration(
    from configuration: CachingConfiguration
  ) -> CachingMiddleware.Configuration {
    let configuredTTL = Self.configuredTTL(for: configuration.duration)
    let defaultTTL = configuredTTL()
    let shouldCache: @Sendable (HTTPRequest, HTTPResponse) -> CacheDecision
    let ttlCalculator: @Sendable (HTTPRequest, HTTPResponse) -> CacheMaxAge
    let useConditionalRequests: CacheRevalidationFlag

    switch configuration.policy {
    case .none:
      shouldCache = { _, _ in false }
      ttlCalculator = { _, _ in defaultTTL }
      useConditionalRequests = false

    case .standard:
      shouldCache = { request, response in
        CacheDecision(
          configuration.shouldCache(request, response).rawValue
            && CachingMiddleware.Configuration.defaultShouldCache(request, response).rawValue
        )
      }
      ttlCalculator = { _, response in
        CachingMiddleware.Configuration.responseTTL(from: response) ?? configuredTTL()
      }
      useConditionalRequests = true

    case .aggressive:
      shouldCache = configuration.shouldCache
      ttlCalculator = { _, _ in configuredTTL() }
      useConditionalRequests = true

    case .custom(let maxAge, let revalidate):
      shouldCache = configuration.shouldCache
      ttlCalculator = { _, _ in maxAge }
      useConditionalRequests = revalidate
    }

    return CachingMiddleware.Configuration(
      defaultTTL: defaultTTL,
      maxCacheSize: nil,
      shouldCache: shouldCache,
      ttlCalculator: ttlCalculator,
      useConditionalRequests: useConditionalRequests
    )
  }

  private static func configuredTTL(
    for duration: CacheDuration
  ) -> @Sendable () -> CacheMaxAge {
    switch duration {
    case .ttl(let ttl):
      return { CacheMaxAge(max(ttl.rawValue, 0)) }

    case .until(let date):
      return { CacheMaxAge(max(date.timeIntervalSinceNow, 0)) }

    case .session, .forever:
      return { CacheMaxAge(Date.distantFuture.timeIntervalSinceNow) }
    }
  }

  private static func createCacheStorage(
    from storage: CacheStorage
  ) throws -> any CachingMiddleware.CacheStorage {
    switch storage {
    case .memory(let size):
      return AdvancedMemoryCacheStorage(sizePolicy: .maxMemory(size.bytes))

    case .disk(let size, let path):
      return try DiskCacheStorage(
        cacheDirectory: try Self.cacheDirectory(from: path),
        sizePolicy: .maxDiskSize(size.bytes)
      )

    case .hybrid(let memorySize, let diskSize, let path):
      return try HybridCacheStorage(
        memorySizePolicy: .maxMemory(memorySize.bytes),
        diskSizePolicy: .maxDiskSize(diskSize.bytes),
        cacheDirectory: try Self.cacheDirectory(from: path)
      )
    }
  }

  private static func cacheDirectory(from path: CacheStoragePath?) throws -> CacheDirectoryURL? {
    guard let path else { return nil }
    guard !path.rawValue.isEmpty else {
      throw CacheConfigurationError.emptyStoragePath
    }

    return CacheDirectoryURL(URL(fileURLWithPath: path.rawValue, isDirectory: true))
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
      maxRefreshAttempts: RetryAttemptCount(rawValue: 1),
      shouldAuthenticate: config.shouldAuthenticate
    )

    return AuthenticationMiddleware(
      configuration: middlewareConfig,
      tokenProvider: tokenProvider,
      client: client
    )
  }
}

private enum CacheConfigurationError: Error {
  case emptyStoragePath
}

/// Middleware that adds a base URL to requests that don't have a complete URL.
private struct BaseURLMiddleware: HTTPRequestMiddleware {
  private let baseURL: HTTPRequestURL

  init(baseURL: HTTPRequestURL) {
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
        timeout: request.timeoutOverride
      )
    }
    return request
  }
}

/// Middleware that adds default headers to all requests.
private struct DefaultHeadersMiddleware: HTTPRequestMiddleware {
  private let headers: HTTPHeaders

  init(headers: HTTPHeaders) {
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
      timeout: request.timeoutOverride
    )
  }
}
