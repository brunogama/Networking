/// Protocol for error handling middleware.
public protocol HTTPErrorMiddleware: Sendable {
  /// Handles errors during request execution.
  /// - Parameters:
  ///   - error: The error that occurred
  ///   - request: The original request
  /// - Returns: A recovered response, or rethrows the error
  /// - Throws: HTTPError if error cannot be handled
  func handleError(
    _ error: HTTPError,
    for request: HTTPRequest
  ) async throws -> HTTPResponse
}
