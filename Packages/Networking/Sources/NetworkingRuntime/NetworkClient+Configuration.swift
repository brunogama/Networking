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

    Self.validateConfiguration(&config)
    let middlewares = Self.configureMiddlewareChain(from: config)

    self.init(
      session: config.session,
      requestMiddlewares: middlewares.request,
      responseMiddlewares: middlewares.response,
      errorMiddlewares: middlewares.error
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

  // Configures the complete middleware chain from configuration.
  // swiftlint:disable:next cyclomatic_complexity function_body_length
  private static func configureMiddlewareChain(
    from config: NetworkClientBuilder.Configuration
  ) -> MiddlewareChain {
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

    return MiddlewareChain(
      request: requestMiddlewares,
      response: responseMiddlewares,
      error: errorMiddlewares
    )
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
        timeout: request.timeout
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
      timeout: request.timeout
    )
  }
}
