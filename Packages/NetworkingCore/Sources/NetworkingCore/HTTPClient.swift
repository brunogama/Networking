/// Core protocol for executing HTTP requests with modern Swift concurrency.
public protocol HTTPClient: Sendable {
  /// Executes an HTTP request asynchronously.
  /// - Parameter request: The HTTP request to execute
  /// - Returns: The HTTP response
  /// - Throws: HTTPError if the request fails
  func execute(_ request: HTTPRequest) async throws -> HTTPResponse
}
