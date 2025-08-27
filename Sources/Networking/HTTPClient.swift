import Foundation

/// Core protocol for executing HTTP requests with modern Swift concurrency.
public protocol HTTPClient: Sendable {
  /// Executes an HTTP request asynchronously.
  /// - Parameter request: The HTTP request to execute
  /// - Returns: The HTTP response
  /// - Throws: HTTPError if the request fails
  func execute(_ request: HTTPRequest) async throws -> HTTPResponse
}

/// Protocol for request modification middleware.
public protocol HTTPRequestMiddleware: Sendable {
  /// Modifies a request before execution.
  /// - Parameter request: The original request
  /// - Returns: The modified request
  /// - Throws: HTTPError if modification fails
  func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest
}

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
