import Foundation
import NetworkingCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct SessionConfiguration: Sendable {
  public let timeout: SessionRequestTimeout
  public let allowsCellularAccess: SessionAllowsCellularAccess
  public let allowsExpensiveNetworkAccess: SessionAllowsExpensiveNetworkAccess
  public let allowsConstrainedNetworkAccess: SessionAllowsConstrainedNetworkAccess
  public let waitsForConnectivity: SessionWaitsForConnectivity
  public let httpMaximumConnectionsPerHost: HostConnectionLimit
  public let requestCachePolicy: URLRequest.CachePolicy
  public let protocolClasses: [AnyClass]?

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

  public func createURLSession() -> URLSession {
    let configuration = configuredURLSessionConfiguration()
    return URLSession(configuration: configuration)
  }

  public func createURLSession(
    securityConfiguration: SecurityConfiguration? = nil
  ) -> URLSession {
    let configuration = configuredURLSessionConfiguration()

    #if canImport(Security)
    if let securityConfiguration {
      let validator = SSLPinningValidator(securityConfiguration: securityConfiguration)
      return URLSession(configuration: configuration, delegate: validator, delegateQueue: nil)
    }
    #endif

    return URLSession(configuration: configuration)
  }

  private func configuredURLSessionConfiguration() -> URLSessionConfiguration {
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
    return configuration
  }
}
