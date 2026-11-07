/// Protocol for request modification middleware.
public protocol HTTPRequestMiddleware: Sendable {
  /// Modifies a request before execution.
  /// - Parameter request: The original request
  /// - Returns: The modified request
  /// - Throws: HTTPError if modification fails
  func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest
}
