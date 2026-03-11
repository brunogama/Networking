/// HTTP semantic convention attribute keys shared across observability modules.
public enum HTTPSemanticAttributes {
  public static let httpMethod = "http.request.method"
  public static let httpUrl = "url.full"
  public static let httpStatusCode = "http.response.status_code"
  public static let httpRequestBodySize = "http.request.body.size"
  public static let httpResponseBodySize = "http.response.body.size"
  public static let httpHost = "server.address"
  public static let httpPort = "server.port"
  public static let httpPath = "url.path"
  public static let httpScheme = "url.scheme"
  public static let userAgentOriginal = "user_agent.original"
  public static let networkProtocolName = "network.protocol.name"
  public static let networkProtocolVersion = "network.protocol.version"
}
