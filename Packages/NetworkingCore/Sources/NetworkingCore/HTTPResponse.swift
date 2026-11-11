/// A structure representing an HTTP response with Swift 6 concurrency compliance.
public struct HTTPResponse: Sendable {
  // MARK: - Properties

  public let request: HTTPRequest

  public let status: HTTPStatus

  public let headers: HTTPHeaders

  public let body: HTTPBody?

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

}
