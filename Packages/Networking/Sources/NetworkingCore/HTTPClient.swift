import Foundation

/// Core protocol for executing HTTP requests with modern Swift concurrency.
public protocol HTTPClient: Sendable {
  /// Executes an HTTP request asynchronously.
  /// - Parameter request: The HTTP request to execute
  /// - Returns: The HTTP response
  /// - Throws: HTTPError if the request fails
  func execute(_ request: HTTPRequest) async throws -> HTTPResponse
}

/// Byte counts reported by a native file transfer task.
package struct HTTPFileTransferProgress: Sendable, Hashable {
  package let transferredBytes: Int64
  package let totalBytes: Int64?

  package init(transferredBytes: Int64, totalBytes: Int64?) {
    self.transferredBytes = transferredBytes
    self.totalBytes = totalBytes
  }
}

/// A file downloaded to URLSession's temporary storage with its HTTP response.
package struct HTTPFileDownload: Sendable {
  package let temporaryFileURL: URL
  package let response: HTTPResponse

  package init(temporaryFileURL: URL, response: HTTPResponse) {
    self.temporaryFileURL = temporaryFileURL
    self.response = response
  }
}

/// Native file transfer operations supported by an HTTP client.
package protocol HTTPFileTransferClient: HTTPClient {
  var canPerformNativeFileTransfer: Bool { get }

  func upload(
    _ request: HTTPRequest,
    fromFile fileURL: URL,
    progress: (@Sendable (HTTPFileTransferProgress) -> Void)?
  ) async throws -> HTTPResponse

  func download(
    _ request: HTTPRequest,
    progress: (@Sendable (HTTPFileTransferProgress) -> Void)?
  ) async throws -> HTTPFileDownload
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
