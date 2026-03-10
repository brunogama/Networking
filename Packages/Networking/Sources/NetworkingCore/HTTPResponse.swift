import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A structure representing an HTTP response with Swift 6 concurrency compliance.
public struct HTTPResponse: Sendable {
  // MARK: - Properties

  /// The original request that generated this response
  public let request: HTTPRequest

  /// The HTTP status code
  public let status: HTTPStatus

  /// Response headers
  public let headers: HTTPHeaders

  /// Response body data
  public let body: HTTPBody?

  /// The response URL (may differ from request URL due to redirects)
  public let url: HTTPResponseURL?

  // MARK: - Initialization

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

  // MARK: - Convenience Initializers

  package init(
    request: HTTPRequest,
    status: HTTPStatus,
    headers: [String: String] = [:],
    body: Data? = nil,
    url: URL? = nil
  ) {
    self.init(
      request: request,
      status: status,
      headers: HTTPHeaders(headers),
      body: body.map { HTTPBody($0) },
      url: url.map { HTTPResponseURL($0) }
    )
  }

  package init(request: HTTPRequest, httpURLResponse: HTTPURLResponse, body: HTTPBody?) {
    self.request = request
    self.status = HTTPStatus(rawValue: HTTPStatusCode(httpURLResponse.statusCode))
    self.headers = HTTPHeaders(
      Dictionary(
        uniqueKeysWithValues:
          httpURLResponse.allHeaderFields.compactMap { key, value in
            guard let keyString = key as? String,
              let valueString = value as? String
            else {
              return nil
            }
            return (keyString, valueString)
          }
      )
    )
    self.body = body
    self.url = httpURLResponse.url.map { HTTPResponseURL($0) }
  }

  package var bodyValue: Data? {
    body?.rawValue
  }

  package var headersValue: [String: String] {
    headers.rawValue
  }

  package var urlValue: URL? {
    url?.rawValue
  }
}
