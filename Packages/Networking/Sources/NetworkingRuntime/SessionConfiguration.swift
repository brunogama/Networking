import Foundation
import NetworkingCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

#if canImport(Network)
import Network
#endif

/// URLSession transport settings applied before optional TLS and pinning policies.
public struct SessionConfiguration: Sendable {
  /// Request timeout in seconds.
  public let timeout: SessionRequestTimeout
  /// Whether requests may use cellular data.
  public let allowsCellularAccess: SessionAllowsCellularAccess
  /// Whether requests may use expensive networks.
  public let allowsExpensiveNetworkAccess: SessionAllowsExpensiveNetworkAccess
  /// Whether requests may use constrained networks.
  public let allowsConstrainedNetworkAccess: SessionAllowsConstrainedNetworkAccess
  /// Whether a request waits for connectivity when supported by the platform.
  public let waitsForConnectivity: SessionWaitsForConnectivity
  /// Maximum simultaneous connections to one host.
  public let httpMaximumConnectionsPerHost: HostConnectionLimit
  /// Foundation cache policy used by the session.
  public let requestCachePolicy: URLRequest.CachePolicy
  /// Explicit URL protocol handlers, or nil for platform defaults.
  public let protocolClasses: [AnyClass]?

  /// Captures transport settings used when creating a URLSession.
  public init(
    timeout: SessionRequestTimeout = SessionRequestTimeout(rawValue: 60.0),
    allowsCellularAccess: SessionAllowsCellularAccess =
      SessionAllowsCellularAccess(rawValue: true),
    allowsExpensiveNetworkAccess: SessionAllowsExpensiveNetworkAccess =
      SessionAllowsExpensiveNetworkAccess(rawValue: true),
    allowsConstrainedNetworkAccess: SessionAllowsConstrainedNetworkAccess =
      SessionAllowsConstrainedNetworkAccess(rawValue: true),
    waitsForConnectivity: SessionWaitsForConnectivity =
      SessionWaitsForConnectivity(rawValue: false),
    httpMaximumConnectionsPerHost: HostConnectionLimit = HostConnectionLimit(rawValue: 6),
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

  /// Creates a session using the configured transport policy and platform trust.
  public func createURLSession() -> URLSession {
    let configuration = configuredURLSessionConfiguration()
    return URLSession(configuration: configuration)
  }

  /// Creates a session with optional TLS requirements and a certificate validation delegate.
  public func createURLSession(
    securityConfiguration: SecurityConfiguration? = nil
  ) -> URLSession {
    let configuration = configuredURLSessionConfiguration(
      securityConfiguration: securityConfiguration
    )

    #if canImport(Security)
    if let securityConfiguration {
      let validator = SSLPinningValidator(securityConfiguration: securityConfiguration)
      return URLSession(configuration: configuration, delegate: validator, delegateQueue: nil)
    }
    #endif

    return URLSession(configuration: configuration)
  }

  func configuredURLSessionConfiguration(
    securityConfiguration: SecurityConfiguration? = nil
  ) -> URLSessionConfiguration {
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = timeout.rawValue
    configuration.allowsCellularAccess = allowsCellularAccess.rawValue
    #if !os(Linux)
    configuration.allowsExpensiveNetworkAccess = allowsExpensiveNetworkAccess.rawValue
    configuration.allowsConstrainedNetworkAccess = allowsConstrainedNetworkAccess.rawValue
    configuration.waitsForConnectivity = waitsForConnectivity.rawValue
    #endif
    configuration.httpMaximumConnectionsPerHost = httpMaximumConnectionsPerHost.rawValue
    configuration.requestCachePolicy = requestCachePolicy
    configuration.protocolClasses = protocolClasses
    if let securityConfiguration {
      applyTLSConfiguration(
        securityConfiguration.tlsConfiguration,
        to: configuration
      )
    }
    return configuration
  }

  private func applyTLSConfiguration(
    _ tlsConfiguration: TLSConfiguration,
    to configuration: URLSessionConfiguration
  ) {
    #if canImport(Network)
    configuration.tlsMinimumSupportedProtocolVersion =
      tlsProtocolVersion(for: tlsConfiguration.minimumTLSVersion)
    configuration.tlsMaximumSupportedProtocolVersion =
      tlsProtocolVersion(for: tlsConfiguration.maximumTLSVersion)
    #endif
  }

  #if canImport(Network)
  private func tlsProtocolVersion(
    for version: TLSConfiguration.TLSVersion
  ) -> tls_protocol_version_t {
    switch version {
    case .tls12:
      return .TLSv12
    case .tls13:
      return .TLSv13
    }
  }
  #endif
}
