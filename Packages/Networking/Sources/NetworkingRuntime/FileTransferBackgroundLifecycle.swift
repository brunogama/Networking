import Foundation
import NetworkingCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum BackgroundTransferCompletion: Sendable {
  case success(URL)
  case failure(any Error, downloadedFileURL: URL?)

  var downloadedFileURL: URL? {
    switch self {
    case .success(let fileURL):
      return fileURL
    case .failure(_, let fileURL):
      return fileURL
    }
  }
}

actor BackgroundTransferCoordinator {
  private struct ActiveDownload {
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

  private let fileInspector: FileTransferFileInspector
  private var downloadsByTask: [Int: ActiveDownload] = [:]
  private var taskByTransferID: [UUID: Int] = [:]

  init(configuration: FileTransferConfiguration) {
    self.fileInspector = FileTransferFileInspector(configuration: configuration)
  }

  func resume(
    task: URLSessionDownloadTask,
    transferId: TransferIdentifier,
    progressCallback: ProgressCallback?
  ) async throws -> FileTransferResult {
    let taskKey = task.taskIdentifier
    downloadsByTask[taskKey] = ActiveDownload(
      transferId: transferId,
      startTime: Date(),
      progressCallback: progressCallback,
      task: task
    )
    taskByTransferID[transferId.rawValue] = taskKey

    return try await withTaskCancellationHandler {
      try Task.checkCancellation()

      return try await withCheckedThrowingContinuation { continuation in
        guard var download = downloadsByTask[taskKey] else {
          continuation.resume(throwing: CancellationError())
          return
        }

        download.continuation = continuation
        downloadsByTask[taskKey] = download
        task.resume()
      }
    } onCancel: {
      Task {
        await self.cancelWaitingTransfer(transferId)
      }
    }
  }

  func cancel(_ transferId: TransferIdentifier) async -> TransferResumeData? {
    guard let taskKey = taskByTransferID[transferId.rawValue],
      var download = downloadsByTask[taskKey]
    else {
      return nil
    }

    download.isCancelled = true
    downloadsByTask[taskKey] = download

    return await withCheckedContinuation { continuation in
      download.task.cancel { resumeData in
        continuation.resume(returning: resumeData.map { TransferResumeData($0) })
      }
    }
  }

  func didWriteData(
    task: URLSessionDownloadTask,
    totalBytesWritten: Int64,
    totalBytesExpected: Int64
  ) {
    guard let download = downloadsByTask[task.taskIdentifier] else { return }

    let totalBytes = totalBytesExpected >= 0 ? TransferByteCount(totalBytesExpected) : nil
    let duration = download.duration
    let speed = duration > 0 ? Double(totalBytesWritten) / duration : 0
    download.progressCallback?(
      TransferProgress(
        totalBytes: totalBytes,
        transferredBytes: TransferByteCount(totalBytesWritten),
        phase: .downloading,
        bytesPerSecond: TransferSpeed(speed)
      )
    )
  }

  func didComplete(
    task: URLSessionTask,
    completion: BackgroundTransferCompletion
  ) {
    guard let download = removeDownload(taskKey: task.taskIdentifier) else {
      discardDownloadedFile(from: completion)
      return
    }

    if download.isCancelled {
      discardDownloadedFile(from: completion)
      fail(download, error: FileTransferError.transferCancelled)
      return
    }

    switch completion {
    case .success(let fileURL):
      complete(download, with: fileURL)
    case .failure(let error, _):
      discardDownloadedFile(from: completion)
      fail(download, error: error)
    }
  }

  private func cancelWaitingTransfer(_ transferId: TransferIdentifier) {
    guard let taskKey = taskByTransferID[transferId.rawValue],
      let download = removeDownload(taskKey: taskKey)
    else {
      return
    }

    download.task.cancel()
    download.continuation?.resume(throwing: CancellationError())
  }

  private func removeDownload(taskKey: Int) -> ActiveDownload? {
    guard let download = downloadsByTask.removeValue(forKey: taskKey) else {
      return nil
    }
    taskByTransferID.removeValue(forKey: download.transferId.rawValue)
    return download
  }

  private func complete(_ download: ActiveDownload, with fileURL: URL) {
    do {
      let metadata = try fileInspector.metadata(for: fileURL)
      let duration = download.duration
      let bytesTransferred = metadata.size.rawValue
      let averageSpeed = duration > 0 ? Double(bytesTransferred) / duration : 0

      download.progressCallback?(
        TransferProgress(
          totalBytes: TransferByteCount(bytesTransferred),
          transferredBytes: TransferByteCount(bytesTransferred),
          phase: .completed,
          bytesPerSecond: TransferSpeed(averageSpeed)
        )
      )
      download.continuation?.resume(
        returning: FileTransferResult(
          transferId: download.transferId,
          bytesTransferred: TransferByteCount(bytesTransferred),
          duration: TransferDuration(duration),
          averageSpeed: TransferSpeed(averageSpeed),
          isSuccessful: true,
          fileMetadata: metadata,
          fileURL: LocalFileURL(fileURL)
        )
      )
    } catch {
      try? FileManager.default.removeItem(at: fileURL)
      fail(download, error: error)
    }
  }

  private func fail(_ download: ActiveDownload, error: any Error) {
    download.progressCallback?(
      TransferProgress(
        totalBytes: nil,
        transferredBytes: 0,
        phase: .failed
      )
    )
    download.continuation?.resume(throwing: error)
  }

  private func discardDownloadedFile(from completion: BackgroundTransferCompletion) {
    guard let fileURL = completion.downloadedFileURL else { return }
    try? FileManager.default.removeItem(at: fileURL)
  }
}
