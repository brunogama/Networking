import Foundation

/// A structure representing an HTTP response with Swift 6 concurrency compliance.
public struct HTTPResponse: Sendable {
  // MARK: - Properties

  /// The original request that generated this response.
  public let request: HTTPRequest

  /// The HTTP status code.
  public let status: HTTPStatus

  /// Response headers.
  public let headers: HTTPHeaders

  /// Response body data.
  public let body: HTTPBody?

  /// The final response URL, which may differ after redirects.
  public let url: HTTPResponseURL?

  // MARK: - Initialization

  /// Creates a response, defaulting its URL to the originating request URL.
  public init(
    request: HTTPRequest,
    status: HTTPStatus,
    headers: HTTPHeaders = [:],
    body: HTTPBody? = nil,
    url: HTTPResponseURL? = nil
  ) {
    self.request = request
    self.status = status
    self.headers = headers
    self.body = body
    self.url = url ?? HTTPResponseURL(request.url.rawValue)
  }

}
