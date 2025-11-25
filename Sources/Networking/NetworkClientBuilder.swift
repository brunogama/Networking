import Foundation

/// Configuration builder for NetworkClient using result builders.
@resultBuilder
public struct NetworkClientBuilder {
  /// Intermediate configuration storage.
  public struct Configuration: Sendable {
    public var session: URLSession = .shared
    public var requestMiddlewares: [any HTTPRequestMiddleware] = []
    public var responseMiddlewares: [any HTTPResponseMiddleware] = []
    public var errorMiddlewares: [any HTTPErrorMiddleware] = []
    public var baseURL: URL?
    public var defaultHeaders: [String: String] = [:]
    public var timeout: TimeInterval = 30.0

    // Configuration components storage
    public var authenticationConfiguration: AuthenticationConfiguration?
    public var retryConfiguration: RetryConfiguration?
    public var cachingConfiguration: CachingConfiguration?
    public var sessionConfiguration: SessionConfiguration?
    public var securityConfiguration: SecurityConfiguration?

    public init() {}
  }

  public static func buildBlock(
    _ components: [any ConfigurationComponent]...
  ) -> [any ConfigurationComponent] {
    components.flatMap { $0 }
  }

  public static func buildExpression(
    _ expression: any ConfigurationComponent
  ) -> [any ConfigurationComponent] {
    [expression]
  }

  public static func buildOptional(
    _ component: [any ConfigurationComponent]?
  ) -> [any ConfigurationComponent] {
    component ?? []
  }

  public static func buildEither(
    first component: [any ConfigurationComponent]
  ) -> [any ConfigurationComponent] {
    component
  }

  public static func buildEither(
    second component: [any ConfigurationComponent]
  ) -> [any ConfigurationComponent] {
    component
  }

  public static func buildArray(
    _ components: [[any ConfigurationComponent]]
  ) -> [any ConfigurationComponent] {
    components.flatMap { $0 }
  }
}

// MARK: - Configuration Types

/// Authentication configuration for the network client.
public struct AuthenticationConfiguration: Sendable {
  public let strategy: AuthenticationStrategy
  public let refreshStrategy: AuthRefreshStrategy
  public let headerName: String
  public let shouldAuthenticate: @Sendable (HTTPRequest) -> Bool

  public init(
    strategy: AuthenticationStrategy,
    refreshStrategy: AuthRefreshStrategy = .automatic,
    headerName: String = "Authorization",
    shouldAuthenticate: @escaping @Sendable (HTTPRequest) -> Bool = { _ in true }
  ) {
    self.strategy = strategy
    self.refreshStrategy = refreshStrategy
    self.headerName = headerName
    self.shouldAuthenticate = shouldAuthenticate
  }
}

/// Authentication strategies available for network requests.
public enum AuthenticationStrategy: Sendable {
  case bearerToken(any BearerTokenProvider)
  case basicAuth(username: String, password: String)
  case custom(any CustomAuthProvider)
}

/// Token refresh strategies.
public enum AuthRefreshStrategy: Sendable {
  case none
  case automatic
  case manual(@Sendable () async throws -> String)

  public static func == (lhs: Self, rhs: Self) -> Bool {
    switch (lhs, rhs) {
    case (.none, .none), (.automatic, .automatic):
      return true

    case (.manual, .manual):
      return true  // We can't compare closures, but this is for basic enum comparisons
    default:
      return false
    }
  }
}

/// Bearer token provider protocol.
public protocol BearerTokenProvider: Sendable {
  func getCurrentToken() async throws -> String?
  func refreshToken() async throws -> String
}

/// Custom authentication provider protocol.
public protocol CustomAuthProvider: Sendable {
  func authenticateRequest(_ request: HTTPRequest) async throws -> HTTPRequest
  func handleAuthenticationError(
    _ error: HTTPError,
    for request: HTTPRequest
  ) async throws -> HTTPResponse?
}

/// Retry configuration for the network client.
public struct RetryConfiguration: Sendable {
  public let maxAttempts: Int
  public let backoffStrategy: RetryBackoffStrategy
  public let retryCondition: @Sendable (HTTPError) -> Bool
  public let delay: TimeInterval

  public init(
    maxAttempts: Int = 3,
    backoffStrategy: RetryBackoffStrategy = .exponential,
    delay: TimeInterval = 1.0,
    retryCondition: @escaping @Sendable (HTTPError) -> Bool = Self.defaultRetryCondition
  ) {
    self.maxAttempts = maxAttempts
    self.backoffStrategy = backoffStrategy
    self.delay = delay
    self.retryCondition = retryCondition
  }

  public static func defaultRetryCondition(_ error: HTTPError) -> Bool {
    switch error.category {
    case .network(.serverUnreachable), .network(.connectionLost), .timeout:
      return true

    case .http(let status) where status.rawValue >= 500:
      return true

    default:
      return false
    }
  }
}

/// Backoff strategies for retry attempts.
public enum RetryBackoffStrategy: Sendable {
  case fixed
  case linear
  case exponential
  case custom(@Sendable (Int) -> TimeInterval)

  public func calculateDelay(for attempt: Int, baseDelay: TimeInterval) -> TimeInterval {
    switch self {
    case .fixed:
      return baseDelay

    case .linear:
      return baseDelay * TimeInterval(attempt)

    case .exponential:
      return baseDelay * pow(2.0, TimeInterval(attempt - 1))

    case .custom(let calculator):
      return calculator(attempt)
    }
  }
}

/// Caching configuration for the network client.
public struct CachingConfiguration: Sendable {
  public let policy: CachingPolicy
  public let storage: CacheStorage
  public let duration: CacheDuration
  public let shouldCache: @Sendable (HTTPRequest, HTTPResponse) -> Bool

  public init(
    policy: CachingPolicy = .standard,
    storage: CacheStorage = .memory(size: .MB(50)),
    duration: CacheDuration = .ttl(300),  // 5 minutes
    shouldCache: @escaping @Sendable (HTTPRequest, HTTPResponse) -> Bool = Self.defaultShouldCache
  ) {
    self.policy = policy
    self.storage = storage
    self.duration = duration
    self.shouldCache = shouldCache
  }

  public static func defaultShouldCache(_ request: HTTPRequest, _ response: HTTPResponse) -> Bool {
    // Only cache GET requests with successful responses
    request.method == .get && response.status.isSuccess
  }
}

/// Caching policies available.
public enum CachingPolicy: Sendable {
  case none
  case standard
  case aggressive
  case custom(maxAge: TimeInterval, revalidate: Bool)
}

/// Cache storage options.
public enum CacheStorage: Sendable {
  case memory(size: StorageSize)
  case disk(size: StorageSize, path: String?)
  case hybrid(memorySize: StorageSize, diskSize: StorageSize, path: String?)
}

/// Storage size specifications.
public enum StorageSize: Sendable {
  case KB(Int)
  case MB(Int)
  case GB(Int)

  public var bytes: Int64 {
    switch self {
    case .KB(let value): return Int64(value) * 1024
    case .MB(let value): return Int64(value) * 1024 * 1024
    case .GB(let value): return Int64(value) * 1024 * 1024 * 1024
    }
  }
}

/// Cache duration options.
public enum CacheDuration: Sendable {
  case ttl(TimeInterval)  // Time to live in seconds
  case until(Date)
  case session  // Until app termination
  case forever
}

/// Session configuration for URLSession setup.
public struct SessionConfiguration: Sendable {
  public let timeout: TimeInterval
  public let allowsCellularAccess: Bool
  public let allowsExpensiveNetworkAccess: Bool
  public let allowsConstrainedNetworkAccess: Bool
  public let waitsForConnectivity: Bool
  public let httpMaximumConnectionsPerHost: Int
  public let requestCachePolicy: URLRequest.CachePolicy
  public let protocolClasses: [AnyClass]?

  public init(
    timeout: TimeInterval = 60.0,
    allowsCellularAccess: Bool = true,
    allowsExpensiveNetworkAccess: Bool = true,
    allowsConstrainedNetworkAccess: Bool = true,
    waitsForConnectivity: Bool = false,
    httpMaximumConnectionsPerHost: Int = 6,
    requestCachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
    protocolClasses: [AnyClass]? = nil
  ) {
    self.timeout = timeout
    self.allowsCellularAccess = allowsCellularAccess
    self.allowsExpensiveNetworkAccess = allowsExpensiveNetworkAccess
    self.allowsConstrainedNetworkAccess = allowsConstrainedNetworkAccess
    self.waitsForConnectivity = waitsForConnectivity
    self.httpMaximumConnectionsPerHost = httpMaximumConnectionsPerHost
    self.requestCachePolicy = requestCachePolicy
    self.protocolClasses = protocolClasses
  }

  /// Creates a URLSession with this configuration
  public func createURLSession() -> URLSession {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = timeout
    config.allowsCellularAccess = allowsCellularAccess
    config.allowsExpensiveNetworkAccess = allowsExpensiveNetworkAccess
    config.allowsConstrainedNetworkAccess = allowsConstrainedNetworkAccess
    config.waitsForConnectivity = waitsForConnectivity
    config.httpMaximumConnectionsPerHost = httpMaximumConnectionsPerHost
    config.requestCachePolicy = requestCachePolicy

    if let protocolClasses = protocolClasses {
      config.protocolClasses = protocolClasses
    }

    return URLSession(configuration: config)
  }

  /// Creates a URLSession with security configuration and delegate
  public func createURLSession(
    securityConfiguration: SecurityConfiguration? = nil
  ) -> URLSession {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = timeout
    config.allowsCellularAccess = allowsCellularAccess
    config.allowsExpensiveNetworkAccess = allowsExpensiveNetworkAccess
    config.allowsConstrainedNetworkAccess = allowsConstrainedNetworkAccess
    config.waitsForConnectivity = waitsForConnectivity
    config.httpMaximumConnectionsPerHost = httpMaximumConnectionsPerHost
    config.requestCachePolicy = requestCachePolicy

    if let protocolClasses = protocolClasses {
      config.protocolClasses = protocolClasses
    }

    // Create session with security delegate if security configuration is provided
    if let securityConfig = securityConfiguration {
      let sslValidator = SSLPinningValidator(securityConfiguration: securityConfig)
      return URLSession(
        configuration: config,
        delegate: sslValidator,
        delegateQueue: nil
      )
    } else {
      return URLSession(configuration: config)
    }
  }
}
