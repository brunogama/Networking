import Foundation
import NetworkingCore

extension NetworkClient {
  /// Transport options shared by all requests made by a client.
  public struct Configuration: Sendable {
    /// Resolves relative request URLs using Foundation URL resolution.
    public var baseURL: URL?
    /// Default headers; request-specific values take precedence without changing request identity.
    public var defaultHeaders: HTTPHeaders = [:]
    /// The default timeout, overridden by a request-specific timeout.
    public var timeout: RequestTimeout?
    /// The response byte limit; nil leaves response size unrestricted.
    public var maximumResponseBytes: Int?
    /// Optional bounded traffic recording and structured logging.
    public var diagnostics: NetworkDiagnostics?

    /// Creates transport options; negative size limits are rejected during execution.
    public init(
      timeout: RequestTimeout? = nil,
      maximumResponseBytes: Int? = nil,
      diagnostics: NetworkDiagnostics? = nil
    ) {
      self.baseURL = nil
      self.timeout = timeout
      self.maximumResponseBytes = maximumResponseBytes
      self.diagnostics = diagnostics
    }
  }

  func prepare(_ request: HTTPRequest) throws(HTTPError) -> HTTPRequest {
    var headers = configuration.defaultHeaders
    for (name, value) in request.headers { headers[name] = value }
    let url = URL(
      string: request.url.rawValue.relativeString,
      relativeTo: configuration.baseURL
    )?.absoluteURL
    guard let url, url.scheme == "http" || url.scheme == "https", url.host != nil else {
      throw HTTPError(
        category: .configuration("An absolute HTTP URL is required"),
        request: request
      )
    }
    return HTTPRequest(
      method: request.method,
      url: HTTPRequestURL(url),
      headers: headers,
      body: request.body,
      timeout: request.timeoutOverride,
      id: request.id
    )
  }

  /// Creates a client with independently configured middleware stages.
  public convenience init(
    session: URLSession = .shared,
    requestMiddlewares: [any HTTPRequestMiddleware] = [],
    responseMiddlewares: [any HTTPResponseMiddleware] = [],
    errorMiddlewares: [any HTTPErrorMiddleware] = []
  ) {
    self.init(
      session: session,
      middleware: HTTPMiddleware(
        request: requestMiddlewares,
        response: responseMiddlewares,
        error: errorMiddlewares
      )
    )
  }

  /// Creates a client that limits each response body, including middleware output.
  public convenience init(
    session: URLSession = .shared,
    responseMiddlewares: [any HTTPResponseMiddleware] = [],
    maximumResponseBytes: Int
  ) {
    self.init(
      session: session,
      middleware: HTTPMiddleware(response: responseMiddlewares),
      configuration: Configuration(maximumResponseBytes: maximumResponseBytes)
    )
  }
}
