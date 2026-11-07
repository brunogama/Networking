/// Protocol for response processing middleware.
public protocol HTTPResponseMiddleware: Sendable {

  func processResponse(
    _ response: HTTPResponse,
    for request: HTTPRequest
  ) async throws -> HTTPResponse
}
