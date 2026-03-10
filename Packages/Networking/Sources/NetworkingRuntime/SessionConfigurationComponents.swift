// swiftlint:disable file_length
import Foundation
import NetworkingCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

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
  private let timeout: SessionRequestTimeout

  public init(_ timeout: SessionRequestTimeout) {
    self.timeout = SessionRequestTimeout(max(0, timeout.rawValue))
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
  private let allows: SessionAllowsCellularAccess

  public init(
    _ allows: SessionAllowsCellularAccess = SessionAllowsCellularAccess(rawValue: true)
  ) {
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
  private let allows: SessionAllowsExpensiveNetworkAccess

  public init(
    _ allows: SessionAllowsExpensiveNetworkAccess =
      SessionAllowsExpensiveNetworkAccess(rawValue: true)
  ) {
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
  private let allows: SessionAllowsConstrainedNetworkAccess

  public init(
    _ allows: SessionAllowsConstrainedNetworkAccess =
      SessionAllowsConstrainedNetworkAccess(rawValue: true)
  ) {
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
  private let waits: SessionWaitsForConnectivity

  public init(
    _ waits: SessionWaitsForConnectivity = SessionWaitsForConnectivity(rawValue: true)
  ) {
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
  private let maxConnections: HostConnectionLimit

  public init(_ maxConnections: HostConnectionLimit) {
    self.maxConnections = HostConnectionLimit(max(1, maxConnections.rawValue))
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
public typealias Middleware = AddMiddleware
