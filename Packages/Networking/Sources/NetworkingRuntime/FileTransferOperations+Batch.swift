import NetworkingCore

extension FileTransferOperations {
  /// Uploads files with bounded concurrency and returns results in the input order.
  ///
  /// All upload and aggregate-progress tasks finish before this method returns. Failure or
  /// cancellation cancels and joins the remaining uploads. Progress callbacks run serially.
  /// `maxConcurrency` must be positive and limits simultaneous file reads and uploads.
  /// - Throws: Invalid limits, a count mismatch, file validation, transport, or cancellation errors.
  public func uploadFiles(
    from fileURLs: [LocalFileURL],
    to destinationURLs: [RemoteTransferURL],
    maxConcurrency: BatchConcurrencyLimit = 4,
    progressCallback: ProgressCallback? = nil
  ) async throws -> [FileTransferResult] {
    guard maxConcurrency.rawValue > 0 else {
      throw HTTPError(category: .configuration("Batch upload concurrency must be positive"))
    }
    guard fileURLs.count == destinationURLs.count else {
      throw HTTPError(category: .configuration("File URLs and destination URLs count mismatch"))
    }
    let files = Array(zip(fileURLs, destinationURLs))
    guard let progressCallback else {
      return try await uploadBatch(files, limit: maxConcurrency.rawValue, progress: nil)
    }
    let events = AsyncStream<(TransferIdentifier, TransferProgress)>.makeStream()
    async let consumer: Void = Self.consumeBatchProgress(events.stream, callback: progressCallback)
    do {
      let results = try await uploadBatch(
        files,
        limit: maxConcurrency.rawValue,
        progress: events.continuation
      )
      events.continuation.finish()
      await consumer
      return results
    } catch {
      events.continuation.finish()
      await consumer
      throw error
    }
  }

  private func uploadBatch(
    _ files: [(LocalFileURL, RemoteTransferURL)],
    limit: Int,
    progress: AsyncStream<(TransferIdentifier, TransferProgress)>.Continuation?
  ) async throws -> [FileTransferResult] {
    try Task.checkCancellation()
    return try await withThrowingTaskGroup(of: (Int, FileTransferResult).self) { group in
      var nextIndex = min(limit, files.count)
      for index in 0..<nextIndex {
        group.addTask {
          try await self.uploadBatchFile(files[index], index: index, progress: progress)
        }
      }
      var results: [(Int, FileTransferResult)] = []
      for try await result in group {
        results.append(result)
        guard nextIndex < files.count else { continue }
        let index = nextIndex
        nextIndex += 1
        group.addTask {
          try await self.uploadBatchFile(files[index], index: index, progress: progress)
        }
      }
      return results.sorted { $0.0 < $1.0 }.map(\.1)
    }
  }

  private func uploadBatchFile(
    _ file: (LocalFileURL, RemoteTransferURL),
    index: Int,
    progress: AsyncStream<(TransferIdentifier, TransferProgress)>.Continuation?
  ) async throws -> (Int, FileTransferResult) {
    try Task.checkCancellation()
    let result = try await uploadFile(
      from: file.0,
      to: file.1,
      progressCallback: Self.batchProgressCallback(progress)
    )
    try Task.checkCancellation()
    return (index, result)
  }

  nonisolated private static func batchProgressCallback(
    _ continuation: AsyncStream<(TransferIdentifier, TransferProgress)>.Continuation?
  ) -> ProgressCallback? {
    guard let continuation else { return nil }
    let identifier = TransferIdentifier()
    return { continuation.yield((identifier, $0)) }
  }

  nonisolated private static func consumeBatchProgress(
    _ stream: AsyncStream<(TransferIdentifier, TransferProgress)>,
    callback: @escaping ProgressCallback
  ) async {
    let aggregator = ProgressAggregator(callback: callback)
    for await (identifier, progress) in stream {
      await aggregator.updateProgress(for: identifier, progress: progress)
    }
  }
}
