import Foundation
import NetworkingCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

extension BackgroundTransferCoordinator {
  struct ActiveDownload {
    let transferId: TransferIdentifier
    let startTime: Date
    let progressCallback: ProgressCallback?
    let task: URLSessionDownloadTask
    var continuation: CheckedContinuation<FileTransferResult, any Error>?
    var isCancelled = false

    var duration: TimeInterval {
      Date().timeIntervalSince(startTime)
    }
  }
}
