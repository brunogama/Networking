import Foundation
import NetworkingCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

#if !os(Linux)

/// Delegate for handling background transfer events.
final class BackgroundTransferDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
  private let progressStreamManager: ProgressTracking.ProgressStreamManager

  init(progressStreamManager: ProgressTracking.ProgressStreamManager) {
    self.progressStreamManager = progressStreamManager
    super.init()
  }

  func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didFinishDownloadingTo location: URL
  ) {
    // Handle completed download
    // In a real implementation, this would notify the FileTransferOperations actor
  }

  // swiftlint:disable:next function_parameter_count
  func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didWriteData bytesWritten: Int64,
    totalBytesWritten: Int64,
    totalBytesExpectedToWrite: Int64
  ) {
    // LIFECYCLE: Fire-and-forget progress update - safe because:
    // 1. progressStreamManager is actor-isolated (thread-safe)
    // 2. Delegate callbacks run on URLSession's delegate queue (not main)
    // 3. Actor suspension doesn't block delegate queue
    // 4. Progress updates are best-effort (missing one doesn't break functionality)
    Task.detached {
      // Map URLSessionTask.taskIdentifier to UUID (FileTransferOperations tracks mapping)
      let transferId = TransferIdentifier()
      // TODO: Retrieve from activeTransfers[downloadTask.taskIdentifier]

      await self.progressStreamManager.bridgeDownloadProgress(
        for: transferId,
        bytesWritten: TransferByteCount(bytesWritten),
        totalBytesWritten: TransferByteCount(totalBytesWritten),
        totalBytesExpected: TransferByteCount(totalBytesExpectedToWrite)
      )
    }
  }

  func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didResumeAtOffset fileOffset: Int64,
    expectedTotalBytes: Int64
  ) {
    // Handle resumed download
    // In a real implementation, this would update the transfer state
  }

  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didCompleteWithError error: (any Error)?
  ) {
    // Handle task completion or error
    // In a real implementation, this would notify the FileTransferOperations actor
  }
}

#endif
