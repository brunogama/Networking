/// HTTP semantic convention attribute keys shared across observability modules.
public enum HTTPSemanticAttributes {
  /// Attribute key for the request method.
  public static let httpMethod = "http.request.method"
  /// Attribute key for the full URL; callers must redact sensitive components.
  public static let httpUrl = "url.full"
  /// Attribute key for the numeric response status.
  public static let httpStatusCode = "http.response.status_code"
  /// Attribute key for the request body size in bytes.
  public static let httpRequestBodySize = "http.request.body.size"
  /// Attribute key for the response body size in bytes.
  public static let httpResponseBodySize = "http.response.body.size"
  /// Attribute key for the server address.
  public static let httpHost = "server.address"
  /// Attribute key for the server port.
  public static let httpPort = "server.port"
  /// Attribute key for the URL path; callers must redact sensitive path segments.
  public static let httpPath = "url.path"
  /// Attribute key for the URL scheme.
  public static let httpScheme = "url.scheme"
  /// Attribute key for the original user-agent value.
  public static let userAgentOriginal = "user_agent.original"
  /// Attribute key for the network protocol name.
  public static let networkProtocolName = "network.protocol.name"
  /// Attribute key for the network protocol version.
  public static let networkProtocolVersion = "network.protocol.version"
}
