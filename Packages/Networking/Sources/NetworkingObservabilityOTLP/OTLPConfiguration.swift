import Foundation
import NetworkingCore

/// Explicit configuration for awaited OTLP HTTP protobuf exports.
public struct OTLPConfiguration: Sendable {

  public let endpoint: HTTPRequestURL

  public let resource: OTLPResource

  public let headers: HTTPHeaders

  public let timeout: RequestTimeout

  public var redactedAttributes: Set<TraceAttributeKey> = Self.defaultRedactedAttributes

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

  public static let defaultRedactedAttributes: Set<TraceAttributeKey> = [
    "http.request.header.authorization", "http.request.header.cookie",
    "http.request.header.x-api-key", "user.password", "user.token",
  ]

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
