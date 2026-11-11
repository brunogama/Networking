/// Protocol for error handling middleware.
public protocol HTTPErrorMiddleware: Sendable {

  func handleError(
    _ error: HTTPError,
    for request: HTTPRequest
  ) async throws -> HTTPResponse
}
