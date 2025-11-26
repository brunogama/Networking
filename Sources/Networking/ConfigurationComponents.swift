import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Base protocol for network client configuration components.
public protocol ConfigurationComponent: Sendable {
  func apply(to configuration: inout NetworkClientBuilder.Configuration)
}

// MARK: - Basic Configuration Components

public struct ClientBaseURL: ConfigurationComponent {
  private let url: URL

  public init(_ urlString: String) throws {
    guard let url = URL(string: urlString) else {
      throw HTTPError(category: .configuration("Invalid base URL: \(urlString)"))
    }
    self.url = url
  }

  public init(_ url: URL) {
    self.url = url
  }

  public func apply(to configuration: inout NetworkClientBuilder.Configuration) {
    configuration.baseURL = url
  }
}

public struct DefaultTimeout: ConfigurationComponent {
  private let timeout: TimeInterval

  public init(_ timeout: TimeInterval) {
    self.timeout = timeout
  }

  public func apply(to configuration: inout NetworkClientBuilder.Configuration) {
    configuration.timeout = timeout
  }
}

public struct DefaultHeader: ConfigurationComponent {
  private let name: String
  private let value: String

  public init(_ name: String, _ value: String) {
    self.name = name
    self.value = value
  }

  public func apply(to configuration: inout NetworkClientBuilder.Configuration) {
    configuration.defaultHeaders[name] = value
  }
}

// MARK: - Middleware Configuration Components

public struct EnableRetry: ConfigurationComponent {
  private let configuration: RetryMiddleware.Configuration

  public init(_ configuration: RetryMiddleware.Configuration = RetryMiddleware.Configuration()) {
    self.configuration = configuration
  }

  public func apply(to configuration: inout NetworkClientBuilder.Configuration) {
    // Note: We need to create a placeholder client for the retry middleware
    // In practice, this would be resolved when the NetworkClient is built
    let retryMiddleware = RetryMiddleware(
      configuration: self.configuration,
      client: NetworkClient()  // This will be replaced with the actual client
    )
    configuration.errorMiddlewares.append(retryMiddleware)
  }
}

#if canImport(OSLog)
public struct EnableLogging: ConfigurationComponent {
  private let configuration: LoggingMiddleware.Configuration

  public init(_ configuration: LoggingMiddleware.Configuration = LoggingMiddleware.Configuration()) {
    self.configuration = configuration
  }

  public func apply(to configuration: inout NetworkClientBuilder.Configuration) {
    let loggingMiddleware = LoggingMiddleware(configuration: self.configuration)
    configuration.requestMiddlewares.append(loggingMiddleware)
    configuration.responseMiddlewares.append(loggingMiddleware)
    configuration.errorMiddlewares.append(loggingMiddleware)
  }
}
#endif

public struct CustomSession: ConfigurationComponent {
  private let session: URLSession

  public init(_ session: URLSession) {
    self.session = session
  }

  public func apply(to configuration: inout NetworkClientBuilder.Configuration) {
    configuration.session = session
  }
}

#if canImport(Security)
public struct EnableSecurity: ConfigurationComponent {
  private let securityConfiguration: SecurityConfiguration

  public init(_ configuration: SecurityConfiguration) {
    self.securityConfiguration = configuration
  }

  public func apply(to configuration: inout NetworkClientBuilder.Configuration) {
    configuration.securityConfiguration = securityConfiguration
  }
}
#endif

// MARK: - Fluent Configuration DSL Components

/// Authentication configuration block using result builders.
public struct Authentication: ConfigurationComponent {
  private let components: [any AuthenticationComponent]

  public init(@AuthenticationBuilder _ content: () -> [any AuthenticationComponent]) {
    self.components = content()
  }

  public func apply(to configuration: inout NetworkClientBuilder.Configuration) {
    var authConfig = AuthenticationConfiguration(
      strategy: AuthenticationStrategy.bearerToken(StaticTokenProvider(token: "")),
      refreshStrategy: AuthRefreshStrategy.automatic
    )

    // Apply authentication components to build the configuration
    for component in components {
      component.apply(to: &authConfig)
    }

    configuration.authenticationConfiguration = authConfig

    // Create and add the authentication middleware
    // Note: This will be properly wired when the NetworkClient is built
  }
}

/// Result builder for authentication configuration.
@resultBuilder
public struct AuthenticationBuilder {
  public static func buildBlock(
    _ components: any AuthenticationComponent...
  ) -> [any AuthenticationComponent] {
    components
  }

  public static func buildOptional(
    _ component: [any AuthenticationComponent]?
  ) -> [any AuthenticationComponent] {
    component ?? []
  }

  public static func buildEither(
    first component: [any AuthenticationComponent]
  ) -> [any AuthenticationComponent] {
    component
  }

  public static func buildEither(
    second component: [any AuthenticationComponent]
  ) -> [any AuthenticationComponent] {
    component
  }

  public static func buildArray(
    _ components: [[any AuthenticationComponent]]
  ) -> [any AuthenticationComponent] {
    components.flatMap { $0 }
  }
}

/// Base protocol for authentication configuration components.
public protocol AuthenticationComponent: Sendable {
  func apply(to configuration: inout AuthenticationConfiguration)
}

// MARK: - Authentication Components

/// Bearer token configuration component.
public struct BearerToken: AuthenticationComponent {
  private let provider: any BearerTokenProvider

  public init(_ token: String) {
    self.provider = StaticTokenProvider(token: token)
  }

  public init(_ provider: any BearerTokenProvider) {
    self.provider = provider
  }

  public func apply(to configuration: inout AuthenticationConfiguration) {
    configuration = AuthenticationConfiguration(
      strategy: AuthenticationStrategy.bearerToken(provider),
      refreshStrategy: configuration.refreshStrategy,
      headerName: configuration.headerName,
      shouldAuthenticate: configuration.shouldAuthenticate
    )
  }
}

/// Basic authentication configuration component.
public struct ClientBasicAuth: AuthenticationComponent {
  private let username: String
  private let password: String

  public init(username: String, password: String) {
    self.username = username
    self.password = password
  }

  public func apply(to configuration: inout AuthenticationConfiguration) {
    configuration = AuthenticationConfiguration(
      strategy: AuthenticationStrategy.basicAuth(username: username, password: password),
      refreshStrategy: configuration.refreshStrategy,
      headerName: configuration.headerName,
      shouldAuthenticate: configuration.shouldAuthenticate
    )
  }
}

/// Custom authentication configuration component.
public struct CustomAuth: AuthenticationComponent {
  private let provider: any CustomAuthProvider

  public init(_ provider: any CustomAuthProvider) {
    self.provider = provider
  }

  public func apply(to configuration: inout AuthenticationConfiguration) {
    configuration = AuthenticationConfiguration(
      strategy: AuthenticationStrategy.custom(provider),
      refreshStrategy: configuration.refreshStrategy,
      headerName: configuration.headerName,
      shouldAuthenticate: configuration.shouldAuthenticate
    )
  }
}

/// Refresh strategy configuration component.
public struct AuthRefreshStrategyComponent: AuthenticationComponent {
  private let strategy: AuthRefreshStrategy

  public init(_ strategy: AuthRefreshStrategy) {
    self.strategy = strategy
  }

  public static func none() -> Self {
    Self(AuthRefreshStrategy.none)
  }

  public static func automatic() -> Self {
    Self(AuthRefreshStrategy.automatic)
  }

  public static func manual(
    _ handler: @escaping @Sendable () async throws -> String
  ) -> Self {
    Self(AuthRefreshStrategy.manual(handler))
  }

  public func apply(to configuration: inout AuthenticationConfiguration) {
    configuration = AuthenticationConfiguration(
      strategy: configuration.strategy,
      refreshStrategy: strategy,
      headerName: configuration.headerName,
      shouldAuthenticate: configuration.shouldAuthenticate
    )
  }
}

/// Authorization header name configuration component.
public struct AuthorizationHeader: AuthenticationComponent {
  private let headerName: String

  public init(_ name: String) {
    self.headerName = name
  }

  public func apply(to configuration: inout AuthenticationConfiguration) {
    configuration = AuthenticationConfiguration(
      strategy: configuration.strategy,
      refreshStrategy: configuration.refreshStrategy,
      headerName: headerName,
      shouldAuthenticate: configuration.shouldAuthenticate
    )
  }
}

/// Authentication condition configuration component.
public struct AuthenticateWhen: AuthenticationComponent {
  private let condition: @Sendable (HTTPRequest) -> Bool

  public init(_ condition: @escaping @Sendable (HTTPRequest) -> Bool) {
    self.condition = condition
  }

  public static func always() -> Self {
    Self { _ in true }
  }

  public static func never() -> Self {
    Self { _ in false }
  }

  public static func pathMatches(_ pattern: String) -> Self {
    Self { request in
      request.url.path.contains(pattern)
    }
  }

  public static func methodIs(_ method: HTTPMethod) -> Self {
    Self { request in
      request.method == method
    }
  }

  public func apply(to configuration: inout AuthenticationConfiguration) {
    configuration = AuthenticationConfiguration(
      strategy: configuration.strategy,
      refreshStrategy: configuration.refreshStrategy,
      headerName: configuration.headerName,
      shouldAuthenticate: condition
    )
  }
}

// MARK: - Token Provider Implementations

/// A static token provider that stores a single token.
public struct StaticTokenProvider: BearerTokenProvider {
  private let token: String

  public init(token: String) {
    self.token = token
  }

  public func getCurrentToken() async throws -> String? {
    token.isEmpty ? nil : token
  }

  public func refreshToken() async throws -> String {
    throw HTTPError(category: .configuration("Static token provider cannot refresh tokens"))
  }
}

/// A closure-based token provider for dynamic token management.
public struct ClosureBearerTokenProvider: BearerTokenProvider {
  private let getCurrentHandler: @Sendable () async throws -> String?
  private let refreshHandler: @Sendable () async throws -> String

  public init(
    getCurrentToken: @escaping @Sendable () async throws -> String?,
    refreshToken: @escaping @Sendable () async throws -> String
  ) {
    self.getCurrentHandler = getCurrentToken
    self.refreshHandler = refreshToken
  }

  public func getCurrentToken() async throws -> String? {
    try await getCurrentHandler()
  }

  public func refreshToken() async throws -> String {
    try await refreshHandler()
  }
}

// MARK: - Retry Configuration Components

/// Retry configuration block using result builders.
public struct Retry: ConfigurationComponent {
  private let components: [any RetryComponent]

  public init(@RetryBuilder _ content: () -> [any RetryComponent]) {
    self.components = content()
  }

  public func apply(to configuration: inout NetworkClientBuilder.Configuration) {
    var retryConfig = RetryConfiguration()

    // Apply retry components to build the configuration
    for component in components {
      component.apply(to: &retryConfig)
    }

    configuration.retryConfiguration = retryConfig
  }
}

/// Result builder for retry configuration.
@resultBuilder
public struct RetryBuilder {
  public static func buildBlock(_ components: any RetryComponent...) -> [any RetryComponent] {
    components
  }

  public static func buildOptional(_ component: [any RetryComponent]?) -> [any RetryComponent] {
    component ?? []
  }

  public static func buildEither(first component: [any RetryComponent]) -> [any RetryComponent] {
    component
  }

  public static func buildEither(second component: [any RetryComponent]) -> [any RetryComponent] {
    component
  }

  public static func buildArray(_ components: [[any RetryComponent]]) -> [any RetryComponent] {
    components.flatMap { $0 }
  }
}

/// Base protocol for retry configuration components.
public protocol RetryComponent: Sendable {
  func apply(to configuration: inout RetryConfiguration)
}

/// Maximum retry attempts configuration component.
public struct MaxAttempts: RetryComponent {
  private let attempts: Int

  public init(_ attempts: Int) {
    self.attempts = max(0, attempts)
  }

  public func apply(to configuration: inout RetryConfiguration) {
    configuration = RetryConfiguration(
      maxAttempts: attempts,
      backoffStrategy: configuration.backoffStrategy,
      delay: configuration.delay,
      retryCondition: configuration.retryCondition
    )
  }
}

/// Backoff strategy configuration component.
public struct BackoffStrategyComponent: RetryComponent {
  private let strategy: RetryBackoffStrategy

  public init(_ strategy: RetryBackoffStrategy) {
    self.strategy = strategy
  }

  public static func fixed() -> Self {
    Self(RetryBackoffStrategy.fixed)
  }

  public static func linear() -> Self {
    Self(RetryBackoffStrategy.linear)
  }

  public static func exponential() -> Self {
    Self(RetryBackoffStrategy.exponential)
  }

  public static func custom(
    _ calculator: @escaping @Sendable (Int) -> TimeInterval
  ) -> Self {
    Self(RetryBackoffStrategy.custom(calculator))
  }

  public func apply(to configuration: inout RetryConfiguration) {
    configuration = RetryConfiguration(
      maxAttempts: configuration.maxAttempts,
      backoffStrategy: strategy,
      delay: configuration.delay,
      retryCondition: configuration.retryCondition
    )
  }
}

/// Initial delay configuration component.
public struct InitialDelay: RetryComponent {
  private let delay: TimeInterval

  public init(_ delay: TimeInterval) {
    self.delay = max(0, delay)
  }

  public func apply(to configuration: inout RetryConfiguration) {
    configuration = RetryConfiguration(
      maxAttempts: configuration.maxAttempts,
      backoffStrategy: configuration.backoffStrategy,
      delay: delay,
      retryCondition: configuration.retryCondition
    )
  }
}

/// Retry condition configuration component.
public struct RetryWhen: RetryComponent {
  private let condition: @Sendable (HTTPError) -> Bool

  public init(_ condition: @escaping @Sendable (HTTPError) -> Bool) {
    self.condition = condition
  }

  public static func networkErrors() -> Self {
    Self { error in
      switch error.category {
      case .network: return true
      case .timeout: return true
      default: return false
      }
    }
  }

  public static func serverErrors() -> Self {
    Self { error in
      if case .http(let status) = error.category {
        return status.rawValue >= 500
      }
      return false
    }
  }

  public static func statusCodes(_ codes: Set<Int>) -> Self {
    Self { error in
      if case .http(let status) = error.category {
        return codes.contains(status.rawValue)
      }
      return false
    }
  }

  public func apply(to configuration: inout RetryConfiguration) {
    configuration = RetryConfiguration(
      maxAttempts: configuration.maxAttempts,
      backoffStrategy: configuration.backoffStrategy,
      delay: configuration.delay,
      retryCondition: condition
    )
  }
}

// MARK: - Caching Configuration Components

/// Caching configuration block using result builders.
public struct Caching: ConfigurationComponent {
  private let components: [any CachingComponent]

  public init(@CachingBuilder _ content: () -> [any CachingComponent]) {
    self.components = content()
  }

  public func apply(to configuration: inout NetworkClientBuilder.Configuration) {
    var cachingConfig = CachingConfiguration()

    // Apply caching components to build the configuration
    for component in components {
      component.apply(to: &cachingConfig)
    }

    configuration.cachingConfiguration = cachingConfig
  }
}

/// Result builder for caching configuration.
@resultBuilder
public struct CachingBuilder {
  public static func buildBlock(_ components: any CachingComponent...) -> [any CachingComponent] {
    components
  }

  public static func buildOptional(_ component: [any CachingComponent]?) -> [any CachingComponent] {
    component ?? []
  }

  public static func buildEither(
    first component: [any CachingComponent]
  ) -> [any CachingComponent] {
    component
  }

  public static func buildEither(
    second component: [any CachingComponent]
  ) -> [any CachingComponent] {
    component
  }

  public static func buildArray(_ components: [[any CachingComponent]]) -> [any CachingComponent] {
    components.flatMap { $0 }
  }
}

/// Base protocol for caching configuration components.
public protocol CachingComponent: Sendable {
  func apply(to configuration: inout CachingConfiguration)
}

/// Caching policy configuration component.
public struct Policy: CachingComponent {
  private let policy: CachingPolicy

  public init(_ policy: CachingPolicy) {
    self.policy = policy
  }

  public static func none() -> Self {
    Self(.none)
  }

  public static func standard() -> Self {
    Self(.standard)
  }

  public static func aggressive() -> Self {
    Self(.aggressive)
  }

  public static func custom(maxAge: TimeInterval, revalidate: Bool = true) -> Self {
    Self(.custom(maxAge: maxAge, revalidate: revalidate))
  }

  public func apply(to configuration: inout CachingConfiguration) {
    configuration = CachingConfiguration(
      policy: policy,
      storage: configuration.storage,
      duration: configuration.duration,
      shouldCache: configuration.shouldCache
    )
  }
}

/// Cache storage configuration component.
public struct Storage: CachingComponent {
  private let storage: CacheStorage

  public init(_ storage: CacheStorage) {
    self.storage = storage
  }

  public static func memory(size: StorageSize) -> Self {
    Self(.memory(size: size))
  }

  public static func disk(size: StorageSize, path: String? = nil) -> Self {
    Self(.disk(size: size, path: path))
  }

  public static func hybrid(
    memorySize: StorageSize,
    diskSize: StorageSize,
    path: String? = nil
  ) -> Self {
    Self(.hybrid(memorySize: memorySize, diskSize: diskSize, path: path))
  }

  public func apply(to configuration: inout CachingConfiguration) {
    configuration = CachingConfiguration(
      policy: configuration.policy,
      storage: storage,
      duration: configuration.duration,
      shouldCache: configuration.shouldCache
    )
  }
}

/// Cache duration configuration component.
public struct Duration: CachingComponent {
  private let duration: CacheDuration

  public init(_ duration: CacheDuration) {
    self.duration = duration
  }

  public static func ttl(_ seconds: TimeInterval) -> Self {
    Self(.ttl(seconds))
  }

  public static func until(_ date: Date) -> Self {
    Self(.until(date))
  }

  public static func session() -> Self {
    Self(.session)
  }

  public static func forever() -> Self {
    Self(.forever)
  }

  public func apply(to configuration: inout CachingConfiguration) {
    configuration = CachingConfiguration(
      policy: configuration.policy,
      storage: configuration.storage,
      duration: duration,
      shouldCache: configuration.shouldCache
    )
  }
}

/// Cache condition configuration component.
public struct CacheWhen: CachingComponent {
  private let condition: @Sendable (HTTPRequest, HTTPResponse) -> Bool

  public init(_ condition: @escaping @Sendable (HTTPRequest, HTTPResponse) -> Bool) {
    self.condition = condition
  }

  public static func always() -> Self {
    Self { _, _ in true }
  }

  public static func never() -> Self {
    Self { _, _ in false }
  }

  public static func getRequestsOnly() -> Self {
    Self { request, _ in request.method == .get }
  }

  public static func successfulResponses() -> Self {
    Self { _, response in response.status.isSuccess }
  }

  public static func statusCodes(_ codes: Set<Int>) -> Self {
    Self { _, response in codes.contains(response.status.rawValue) }
  }

  public func apply(to configuration: inout CachingConfiguration) {
    configuration = CachingConfiguration(
      policy: configuration.policy,
      storage: configuration.storage,
      duration: configuration.duration,
      shouldCache: condition
    )
  }
}

// MARK: - Session Configuration Components

/// Session configuration block using result builders.
public struct Session: ConfigurationComponent {
  private let components: [any SessionComponent]

  public init(@SessionBuilder _ content: () -> [any SessionComponent]) {
    self.components = content()
  }

  public func apply(to configuration: inout NetworkClientBuilder.Configuration) {
    var sessionConfig = SessionConfiguration()

    // Apply session components to build the configuration
    for component in components {
      component.apply(to: &sessionConfig)
    }

    configuration.sessionConfiguration = sessionConfig
    // Create the URLSession with the configuration
    configuration.session = sessionConfig.createURLSession()
  }
}

/// Result builder for session configuration.
@resultBuilder
public struct SessionBuilder {
  public static func buildBlock(_ components: any SessionComponent...) -> [any SessionComponent] {
    components
  }

  public static func buildOptional(_ component: [any SessionComponent]?) -> [any SessionComponent] {
    component ?? []
  }

  public static func buildEither(
    first component: [any SessionComponent]
  ) -> [any SessionComponent] {
    component
  }

  public static func buildEither(
    second component: [any SessionComponent]
  ) -> [any SessionComponent] {
    component
  }

  public static func buildArray(_ components: [[any SessionComponent]]) -> [any SessionComponent] {
    components.flatMap { $0 }
  }
}

/// Base protocol for session configuration components.
public protocol SessionComponent: Sendable {
  func apply(to configuration: inout SessionConfiguration)
}

/// Session timeout configuration component.
public struct SessionTimeout: SessionComponent {
  private let timeout: TimeInterval

  public init(_ timeout: TimeInterval) {
    self.timeout = max(0, timeout)
  }

  public func apply(to configuration: inout SessionConfiguration) {
    configuration = SessionConfiguration(
      timeout: timeout,
      allowsCellularAccess: configuration.allowsCellularAccess,
      allowsExpensiveNetworkAccess: configuration.allowsExpensiveNetworkAccess,
      allowsConstrainedNetworkAccess: configuration.allowsConstrainedNetworkAccess,
      waitsForConnectivity: configuration.waitsForConnectivity,
      httpMaximumConnectionsPerHost: configuration.httpMaximumConnectionsPerHost,
      requestCachePolicy: configuration.requestCachePolicy,
      protocolClasses: configuration.protocolClasses
    )
  }
}

/// Cellular access configuration component.
public struct AllowsCellular: SessionComponent {
  private let allows: Bool

  public init(_ allows: Bool = true) {
    self.allows = allows
  }

  public func apply(to configuration: inout SessionConfiguration) {
    configuration = SessionConfiguration(
      timeout: configuration.timeout,
      allowsCellularAccess: allows,
      allowsExpensiveNetworkAccess: configuration.allowsExpensiveNetworkAccess,
      allowsConstrainedNetworkAccess: configuration.allowsConstrainedNetworkAccess,
      waitsForConnectivity: configuration.waitsForConnectivity,
      httpMaximumConnectionsPerHost: configuration.httpMaximumConnectionsPerHost,
      requestCachePolicy: configuration.requestCachePolicy,
      protocolClasses: configuration.protocolClasses
    )
  }
}

/// Expensive network access configuration component.
public struct AllowsExpensiveNetworkAccess: SessionComponent {
  private let allows: Bool

  public init(_ allows: Bool = true) {
    self.allows = allows
  }

  public func apply(to configuration: inout SessionConfiguration) {
    configuration = SessionConfiguration(
      timeout: configuration.timeout,
      allowsCellularAccess: configuration.allowsCellularAccess,
      allowsExpensiveNetworkAccess: allows,
      allowsConstrainedNetworkAccess: configuration.allowsConstrainedNetworkAccess,
      waitsForConnectivity: configuration.waitsForConnectivity,
      httpMaximumConnectionsPerHost: configuration.httpMaximumConnectionsPerHost,
      requestCachePolicy: configuration.requestCachePolicy,
      protocolClasses: configuration.protocolClasses
    )
  }
}

/// Constrained network access configuration component.
public struct AllowsConstrainedNetworkAccess: SessionComponent {
  private let allows: Bool

  public init(_ allows: Bool = true) {
    self.allows = allows
  }

  public func apply(to configuration: inout SessionConfiguration) {
    configuration = SessionConfiguration(
      timeout: configuration.timeout,
      allowsCellularAccess: configuration.allowsCellularAccess,
      allowsExpensiveNetworkAccess: configuration.allowsExpensiveNetworkAccess,
      allowsConstrainedNetworkAccess: allows,
      waitsForConnectivity: configuration.waitsForConnectivity,
      httpMaximumConnectionsPerHost: configuration.httpMaximumConnectionsPerHost,
      requestCachePolicy: configuration.requestCachePolicy,
      protocolClasses: configuration.protocolClasses
    )
  }
}

/// Connectivity waiting configuration component.
public struct WaitsForConnectivity: SessionComponent {
  private let waits: Bool

  public init(_ waits: Bool = true) {
    self.waits = waits
  }

  public func apply(to configuration: inout SessionConfiguration) {
    configuration = SessionConfiguration(
      timeout: configuration.timeout,
      allowsCellularAccess: configuration.allowsCellularAccess,
      allowsExpensiveNetworkAccess: configuration.allowsExpensiveNetworkAccess,
      allowsConstrainedNetworkAccess: configuration.allowsConstrainedNetworkAccess,
      waitsForConnectivity: waits,
      httpMaximumConnectionsPerHost: configuration.httpMaximumConnectionsPerHost,
      requestCachePolicy: configuration.requestCachePolicy,
      protocolClasses: configuration.protocolClasses
    )
  }
}

/// Maximum connections per host configuration component.
public struct MaxConnectionsPerHost: SessionComponent {
  private let maxConnections: Int

  public init(_ maxConnections: Int) {
    self.maxConnections = max(1, maxConnections)
  }

  public func apply(to configuration: inout SessionConfiguration) {
    configuration = SessionConfiguration(
      timeout: configuration.timeout,
      allowsCellularAccess: configuration.allowsCellularAccess,
      allowsExpensiveNetworkAccess: configuration.allowsExpensiveNetworkAccess,
      allowsConstrainedNetworkAccess: configuration.allowsConstrainedNetworkAccess,
      waitsForConnectivity: configuration.waitsForConnectivity,
      httpMaximumConnectionsPerHost: maxConnections,
      requestCachePolicy: configuration.requestCachePolicy,
      protocolClasses: configuration.protocolClasses
    )
  }
}

/// Request cache policy configuration component.
public struct RequestCachePolicy: SessionComponent {
  private let policy: URLRequest.CachePolicy

  public init(_ policy: URLRequest.CachePolicy) {
    self.policy = policy
  }

  public func apply(to configuration: inout SessionConfiguration) {
    configuration = SessionConfiguration(
      timeout: configuration.timeout,
      allowsCellularAccess: configuration.allowsCellularAccess,
      allowsExpensiveNetworkAccess: configuration.allowsExpensiveNetworkAccess,
      allowsConstrainedNetworkAccess: configuration.allowsConstrainedNetworkAccess,
      waitsForConnectivity: configuration.waitsForConnectivity,
      httpMaximumConnectionsPerHost: configuration.httpMaximumConnectionsPerHost,
      requestCachePolicy: policy,
      protocolClasses: configuration.protocolClasses
    )
  }
}

// MARK: - Type Aliases for Configuration

/// Type alias to use BaseURL in both contexts
public typealias BaseURL = ClientBaseURL

/// Type aliases for cleaner API
public typealias BasicAuth = ClientBasicAuth
public typealias BackoffStrategy = BackoffStrategyComponent
public typealias RefreshStrategy = AuthRefreshStrategyComponent
