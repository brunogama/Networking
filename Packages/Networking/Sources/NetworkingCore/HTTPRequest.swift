import Foundation

/// A structure representing an HTTP request with Swift 6 concurrency compliance.
public struct HTTPRequest: Sendable, Identifiable {
  // MARK: - Properties

  /// Unique identifier for this request
  public let id: HTTPRequestID

  /// The HTTP method
  public let method: HTTPMethod

  /// The complete URL for the request
  public let url: HTTPRequestURL

  /// HTTP headers
  public let headers: HTTPHeaders

  /// Request body data
  public let body: HTTPBody?

  /// Request timeout interval
  public let timeout: RequestTimeout

  // MARK: - Initialization

  public init(
    method: HTTPMethod,
    url: HTTPRequestURL,
    headers: HTTPHeaders = [:],
    body: HTTPBody? = nil,
    timeout: RequestTimeout = RequestTimeout(rawValue: 30.0),
    id: HTTPRequestID = .init()
  ) {
    self.id = id
    self.method = method
    self.url = url
    self.headers = headers
    self.body = body
    self.timeout = timeout
  }

  package init(
    method: HTTPMethod,
    url: URL,
    headers: [String: String] = [:],
    body: Data? = nil,
    timeout: TimeInterval = 30.0,
    id: UUID = UUID()
  ) {
    self.init(
      method: method,
      url: HTTPRequestURL(url),
      headers: HTTPHeaders(headers),
      body: body.map { HTTPBody($0) },
      timeout: RequestTimeout(timeout),
      id: HTTPRequestID(id)
    )
  }

  package var urlValue: URL {
    url.rawValue
  }

  package var headersValue: [String: String] {
    headers.rawValue
  }

  package var bodyValue: Data? {
    body?.rawValue
  }

  package var timeoutInterval: TimeInterval {
    timeout.rawValue
  }
}
