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
  public let headers: [String: String]

  /// Response body data
  public let body: Data?

  /// The response URL (may differ from request URL due to redirects)
  public let url: URL?

  // MARK: - Initialization

  public init(
    request: HTTPRequest,
    status: HTTPStatus,
    headers: [String: String] = [:],
    body: Data? = nil,
    url: URL? = nil
  ) {
    self.request = request
    self.status = status
    self.headers = headers
    self.body = body
    self.url = url ?? request.url
  }

  // MARK: - Convenience Initializers

  internal init(request: HTTPRequest, httpURLResponse: HTTPURLResponse, body: Data?) {
    self.request = request
    self.status = HTTPStatus(rawValue: httpURLResponse.statusCode)
    self.headers = Dictionary(
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
    self.body = body
    self.url = httpURLResponse.url
  }
}
