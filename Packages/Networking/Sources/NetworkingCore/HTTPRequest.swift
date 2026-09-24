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

  /// A timeout supplied by the caller, rather than inherited from the client or session.
  package let timeoutOverride: RequestTimeout?

  // MARK: - Initialization

  public init(
    method: HTTPMethod,
    url: HTTPRequestURL,
    headers: HTTPHeaders = [:],
    body: HTTPBody? = nil,
    timeout: RequestTimeout? = nil,
    id: HTTPRequestID = .init()
  ) {
    self.id = id
    self.method = method
    self.url = url
    self.headers = headers
    self.body = body
    self.timeout = timeout ?? RequestTimeout(rawValue: 30.0)
    self.timeoutOverride = timeout
  }

  /// Creates a request from Foundation values, including values known only at runtime.
  public init(
    method: HTTPMethod,
    url: URL,
    headers: [String: String] = [:],
    body: Data? = nil,
    timeout: TimeInterval? = nil,
    id: UUID = UUID()
  ) {
    self.init(
      method: method,
      url: HTTPRequestURL(url),
      headers: HTTPHeaders(headers),
      body: body.map { HTTPBody($0) },
      timeout: timeout.map { RequestTimeout($0) },
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
