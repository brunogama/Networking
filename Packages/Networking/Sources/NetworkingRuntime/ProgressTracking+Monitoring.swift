import Foundation
import NetworkingCore

extension ProgressTracking {
  /// Protocol for objects that can monitor transfer progress
  public protocol ProgressMonitor: Sendable {
    /// Called when progress updates are received
    func progressUpdated(_ update: ProgressUpdate) async

    /// Called when a transfer completes successfully
    func transferCompleted(_ transferId: TransferIdentifier) async

    /// Called when a transfer fails
    func transferFailed(_ transferId: TransferIdentifier, error: any Error) async
  }

  /// Default implementation of progress monitor that logs to console
  public struct ConsoleProgressMonitor: ProgressMonitor {
    public init() {}

    public func progressUpdated(_ update: ProgressUpdate) async {
      let progressBar = createProgressBar(progress: update.progress)
      writeToStandardOutput(
        "[\(update.transferId.uuidString.prefix(8))] \(progressBar) "
          + "\(String(format: "%.1f", update.progress.rawValue * 100))% "
          + "- \(update.formattedSpeed.rawValue)"
      )
    }

    public func transferCompleted(_ transferId: TransferIdentifier) async {
      writeToStandardOutput("[\(transferId.uuidString.prefix(8))] ✅ Transfer completed")
    }

    public func transferFailed(_ transferId: TransferIdentifier, error: any Error) async {
      writeToStandardError(
        "[\(transferId.uuidString.prefix(8))] ❌ Transfer failed: \(error.localizedDescription)"
      )
    }

    private func createProgressBar(progress: TransferProgressFraction) -> String {
      let width = 20
      let filledWidth = Int(progress.rawValue * Double(width))
      let filled = String(repeating: "█", count: filledWidth)
      let empty = String(repeating: "░", count: width - filledWidth)
      return "[\(filled)\(empty)]"
    }

    private func writeToStandardOutput(_ message: String) {
      FileHandle.standardOutput.write(Data("\(message)\n".utf8))
    }

    private func writeToStandardError(_ message: String) {
      FileHandle.standardError.write(Data("\(message)\n".utf8))
    }
  }

  /// Tracks progress for multiple concurrent transfers
  public actor BatchProgressTracker {
    private let streamManager = ProgressStreamManager()
    private var batchTransfers: [TransferIdentifier: BatchTransferInfo] = [:]

    private struct BatchTransferInfo {
      let transferId: TransferIdentifier
      let totalBytes: TransferByteCount?
      var transferredBytes: TransferByteCount = 0
      var phase: TransferPhase = .preparing
      var startTime = Date()
    }

    public init() {}

    /// Starts tracking a batch of transfers
    /// - Parameter transferIds: Array of transfer IDs with their expected sizes
    /// - Returns: Dictionary of progress streams for each transfer
    public func startBatchTracking(
      _ transferIds: [(transferId: TransferIdentifier, totalBytes: TransferByteCount?)]
    ) async -> [TransferIdentifier: AsyncThrowingStream<ProgressUpdate, any Error>] {
      var streams: [TransferIdentifier: AsyncThrowingStream<ProgressUpdate, any Error>] = [:]

      for (transferId, totalBytes) in transferIds {
        let info = BatchTransferInfo(
          transferId: transferId,
          totalBytes: totalBytes
        )
        batchTransfers[transferId] = info

        let stream = await streamManager.createProgressStream(
          for: transferId,
          totalBytes: totalBytes
        )
        streams[transferId] = stream
      }

      return streams
    }

    /// Updates progress for a specific transfer in the batch
    public func updateBatchProgress(
      transferId: TransferIdentifier,
      transferredBytes: TransferByteCount,
      phase: TransferPhase = .downloading
    ) async throws {
      guard var info = batchTransfers[transferId] else {
        throw ProgressError.transferNotFound(transferId)
      }

      info.transferredBytes = transferredBytes
      info.phase = phase
      batchTransfers[transferId] = info

      try await streamManager.updateProgress(
        for: transferId,
        transferredBytes: transferredBytes,
        phase: phase
      )
    }

    /// Completes a transfer in the batch
    public func completeBatchTransfer(
      transferId: TransferIdentifier,
      phase: TransferPhase,
      error: (any Error)? = nil
    ) async {
      await streamManager.completeProgress(
        for: transferId,
        phase: phase,
        error: error
      )

      batchTransfers.removeValue(forKey: transferId)
    }

    /// Returns aggregate progress for all transfers in the batch
    public func getAggregateProgress() async -> ProgressUpdate? {
      let activeTransfers = Array(batchTransfers.values)
      guard !activeTransfers.isEmpty else { return nil }

      let totalBytes = activeTransfers.compactMap(\.totalBytes).reduce(TransferByteCount(0), +)
      let transferredBytes = activeTransfers.map(\.transferredBytes).reduce(TransferByteCount(0), +)

      let allCompleted = activeTransfers.allSatisfy { $0.phase == .completed }
      let anyFailed = activeTransfers.contains { $0.phase == .failed }

      let phase: TransferPhase
      if anyFailed {
        phase = .failed
      } else if allCompleted {
        phase = .completed
      } else {
        phase = activeTransfers.contains { $0.phase == .uploading } ? .uploading : .downloading
      }

      return ProgressUpdate(
        transferId: TransferIdentifier(),  // Aggregate ID
        phase: phase,
        totalBytes: totalBytes > 0 ? totalBytes : nil,
        transferredBytes: transferredBytes
      )
    }
  }
}
