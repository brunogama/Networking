import Foundation

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
