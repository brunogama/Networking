import Foundation
import NetworkingCore

/// Explicit configuration for awaited OTLP HTTP protobuf exports.
public struct OTLPConfiguration: Sendable {
  /// Collector base URL; signal paths are appended to this URL.
  public let endpoint: HTTPRequestURL
  /// Service attributes attached to every export.
  public let resource: OTLPResource
  /// Collector authentication headers; never included in telemetry payloads.
  public let headers: HTTPHeaders
  /// Maximum duration of each export request.
  public let timeout: RequestTimeout
  /// Case-insensitive attribute names omitted from spans, events, and resources.
  public var redactedAttributes: Set<TraceAttributeKey> = Self.defaultRedactedAttributes

  /// Creates explicit export settings; exporters validate them before use.
  public init(
    endpoint: HTTPRequestURL,
    resource: OTLPResource = OTLPResource(),
    headers: HTTPHeaders = [:],
    timeout: RequestTimeout = 10
  ) {
    self.endpoint = endpoint
    self.resource = resource
    self.headers = headers
    self.timeout = timeout
  }

  /// Credential-bearing attributes excluded unless the caller replaces this policy.
  public static let defaultRedactedAttributes: Set<TraceAttributeKey> = [
    "http.request.header.authorization", "http.request.header.cookie",
    "http.request.header.x-api-key", "user.password", "user.token",
  ]

  /// Rejects non-HTTP URLs, URL credentials, invalid hosts, and invalid timeouts.
  public func validate() throws(OTLPConfigurationError) {
    guard ["http", "https"].contains(endpoint.rawValue.scheme ?? ""),
      endpoint.rawValue.host != nil
    else {
      throw .invalidEndpoint
    }
    let components = URLComponents(url: endpoint.rawValue, resolvingAgainstBaseURL: false)
    guard components?.user == nil, components?.password == nil,
      components?.query == nil, components?.fragment == nil
    else { throw .invalidEndpoint }
    guard timeout.rawValue.isFinite, timeout.rawValue > 0 else { throw .invalidTimeout }
  }
}
