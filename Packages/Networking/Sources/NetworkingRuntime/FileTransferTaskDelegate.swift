import Foundation
import NetworkingCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

package final class FileTransferTaskDelegate: NSObject, URLSessionTaskDelegate,
  URLSessionDownloadDelegate, @unchecked Sendable
{
  private let progress: (@Sendable (HTTPFileTransferProgress) -> Void)?

  package init(progress: (@Sendable (HTTPFileTransferProgress) -> Void)?) {
    self.progress = progress
    super.init()
  }

  // swiftlint:disable:next function_parameter_count
  package func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didSendBodyData bytesSent: Int64,
    totalBytesSent: Int64,
    totalBytesExpectedToSend: Int64
  ) {
    progress?(
      HTTPFileTransferProgress(
        transferredBytes: totalBytesSent,
        totalBytes: Self.knownByteCount(totalBytesExpectedToSend)
      )
    )
  }

  package func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didFinishDownloadingTo location: URL
  ) {}

  // swiftlint:disable:next function_parameter_count
  package func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didWriteData bytesWritten: Int64,
    totalBytesWritten: Int64,
    totalBytesExpectedToWrite: Int64
  ) {
    progress?(
      HTTPFileTransferProgress(
        transferredBytes: totalBytesWritten,
        totalBytes: Self.knownByteCount(totalBytesExpectedToWrite)
      )
    )
  }

  private static func knownByteCount(_ byteCount: Int64) -> Int64? {
    byteCount == NSURLSessionTransferSizeUnknown ? nil : byteCount
  }
}
