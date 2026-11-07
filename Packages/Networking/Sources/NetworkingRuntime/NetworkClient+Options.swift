import Foundation
import NetworkingCore

extension NetworkClient {
  /// Transport options shared by all requests made by a client.
  public struct Configuration: Sendable {

    public var baseURL: URL?

    public var defaultHeaders: HTTPHeaders = [:]

    public var timeout: RequestTimeout?

    public var maximumResponseBytes: Int?

    public var diagnostics: NetworkDiagnostics?

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
