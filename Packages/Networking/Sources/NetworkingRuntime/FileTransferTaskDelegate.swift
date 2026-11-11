import Foundation
import os

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

package final class HTTPTaskDelegate: NSObject, URLSessionTaskDelegate,
  URLSessionDownloadDelegate, Sendable
{
  private let progress: (@Sendable (HTTPFileTransferProgress) -> Void)?
  private let diagnostics: NetworkDiagnostics?
  private let traceID: HTTPTraceID?
  private let maximumDownloadBytes: Int64?
  private let downloadLimitExceeded = OSAllocatedUnfairLock(initialState: false)

  package var exceededDownloadLimit: Bool { downloadLimitExceeded.withLock { $0 } }

  package init(
    progress: (@Sendable (HTTPFileTransferProgress) -> Void)? = nil,
    diagnostics: NetworkDiagnostics? = nil,
    traceID: HTTPTraceID? = nil,
    maximumDownloadBytes: Int64? = nil
  ) {
    self.progress = progress
    self.diagnostics = diagnostics
    self.traceID = traceID
    self.maximumDownloadBytes = maximumDownloadBytes
    super.init()
  }

  package func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didFinishCollecting metrics: URLSessionTaskMetrics
  ) {
    guard let traceID else { return }
    diagnostics?.record(traceID, metrics: metrics)
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
    if let limit = maximumDownloadBytes,
      max(totalBytesWritten, totalBytesExpectedToWrite) > limit
    {
      downloadLimitExceeded.withLock { $0 = true }
      downloadTask.cancel()
      return
    }
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
