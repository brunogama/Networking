// swiftlint:disable file_length
import Foundation
import NetworkingCore

#if canImport(FoundationNetworking)
import FoundationNetworking
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

  public init(_ token: BearerTokenValue) {
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
  private let username: BasicAuthUsername
  private let password: BasicAuthPassword

  public init(username: BasicAuthUsername, password: BasicAuthPassword) {
    self.username = username
    self.password = password
  }

  public func apply(to configuration: inout AuthenticationConfiguration) {
    configuration = AuthenticationConfiguration(
      strategy: AuthenticationStrategy.basicAuth(
        username: username,
        password: password
      ),
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
    _ handler: @escaping @Sendable () async throws -> BearerTokenValue
  ) -> Self {
    Self(
      AuthRefreshStrategy.manual {
        try await handler()
      }
    )
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
  private let headerName: HTTPHeaderName

  public init(_ name: HTTPHeaderName) {
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
  private let condition: @Sendable (HTTPRequest) -> AuthenticationDecision

  public init(_ condition: @escaping @Sendable (HTTPRequest) -> AuthenticationDecision) {
    self.condition = condition
  }

  public static func always() -> Self {
    Self { _ in true }
  }

  public static func never() -> Self {
    Self { _ in false }
  }

  public static func pathMatches(_ pattern: RequestPathPattern) -> Self {
    Self { request in
      AuthenticationDecision(request.url.path.contains(pattern.rawValue))
    }
  }

  public static func methodIs(_ method: HTTPMethod) -> Self {
    Self { request in
      AuthenticationDecision(request.method == method)
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
  private let token: BearerTokenValue

  public init(token: BearerTokenValue) {
    self.token = token
  }

  public func getCurrentToken() async throws -> BearerTokenValue? {
    token.isEmpty == true ? nil : token
  }

  public func refreshToken() async throws -> BearerTokenValue {
    throw HTTPError(category: .configuration("Static token provider cannot refresh tokens"))
  }
}

/// A closure-based token provider for dynamic token management.
public struct ClosureBearerTokenProvider: BearerTokenProvider {
  private let getCurrentHandler: @Sendable () async throws -> BearerTokenValue?
  private let refreshHandler: @Sendable () async throws -> BearerTokenValue

  public init(
    getCurrentToken: @escaping @Sendable () async throws -> BearerTokenValue?,
    refreshToken: @escaping @Sendable () async throws -> BearerTokenValue
  ) {
    self.getCurrentHandler = getCurrentToken
    self.refreshHandler = refreshToken
  }

  public func getCurrentToken() async throws -> BearerTokenValue? {
    try await getCurrentHandler()
  }

  public func refreshToken() async throws -> BearerTokenValue {
    try await refreshHandler()
  }
}
