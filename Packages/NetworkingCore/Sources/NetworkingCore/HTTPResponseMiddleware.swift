/// Protocol for response processing middleware.
public protocol HTTPResponseMiddleware: Sendable {
  /// Processes a response after execution.
  /// - Parameters:
  ///   - response: The original response
  ///   - request: The original request
  /// - Returns: The processed response
  /// - Throws: HTTPError if processing fails
  func processResponse(
    _ response: HTTPResponse,
    for request: HTTPRequest
  ) async throws -> HTTPResponse
}
