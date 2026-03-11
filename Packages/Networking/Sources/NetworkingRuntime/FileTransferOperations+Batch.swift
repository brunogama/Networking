import Foundation
import NetworkingCore

extension FileTransferOperations {
  /// Convenience method to upload multiple files concurrently.
  /// - Parameters:
  ///   - fileURLs: Array of local file URLs to upload
  ///   - destinationURLs: Array of remote URLs (must match fileURLs count)
  ///   - progressCallback: Optional callback for aggregate progress updates
  /// - Returns: Array of file transfer results
  public func uploadFiles(
    from fileURLs: [LocalFileURL],
    to destinationURLs: [RemoteTransferURL],
    progressCallback: ProgressCallback? = nil
  ) async throws -> [FileTransferResult] {
    guard fileURLs.count == destinationURLs.count else {
      throw HTTPError(category: .configuration("File URLs and destination URLs count mismatch"))
    }

    let progressAggregator: ProgressAggregator?
    if let progressCallback = progressCallback {
      progressAggregator = ProgressAggregator(callback: progressCallback)
    } else {
      progressAggregator = nil
    }

    var results: [FileTransferResult] = []

    for (fileURL, destinationURL) in zip(fileURLs, destinationURLs) {
      let transferId = TransferIdentifier()

      let individualProgressCallback: ProgressCallback? =
        progressAggregator != nil
        ? { @Sendable progress in
          _ = Task.detached {
            await progressAggregator?.updateProgress(for: transferId, progress: progress)
          }
        } : nil

      let result = try await self.uploadFile(
        from: fileURL,
        to: destinationURL,
        progressCallback: individualProgressCallback
      )

      results.append(result)
    }

    return results
  }
}
