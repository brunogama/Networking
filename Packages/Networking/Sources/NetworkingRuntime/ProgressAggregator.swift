import NetworkingCore

/// Utility for aggregating progress from multiple concurrent transfers.
public actor ProgressAggregator {
  private var activeTransfers: [TransferIdentifier: TransferProgress] = [:]
  private let callback: ProgressCallback

  public init(callback: @escaping ProgressCallback) {
    self.callback = callback
  }

  public func updateProgress(for transferId: TransferIdentifier, progress: TransferProgress) {
    activeTransfers[transferId] = progress

    // Calculate aggregate progress
    let aggregateProgress = calculateAggregateProgress()
    callback(aggregateProgress)

    // Clean up completed transfers
    if progress.phase == .completed || progress.phase == .failed {
      activeTransfers.removeValue(forKey: transferId)
    }
  }

  private func calculateAggregateProgress() -> TransferProgress {
    let transfers = Array(activeTransfers.values)

    guard !transfers.isEmpty else {
      return TransferProgress(totalBytes: 0, transferredBytes: 0, phase: .completed)
    }

    let totalBytes = transfers.compactMap { $0.totalBytes?.rawValue }.reduce(Int64(0), +)
    let transferredBytes = transfers.map { $0.transferredBytes.rawValue }.reduce(Int64(0), +)

    let hasTotal = totalBytes > 0
    let allCompleted = transfers.allSatisfy { $0.phase == .completed }
    let anyFailed = transfers.contains { $0.phase == .failed }

    let phase: TransferPhase
    if anyFailed {
      phase = .failed
    } else if allCompleted {
      phase = .completed
    } else {
      phase = transfers.contains { $0.phase == .uploading } ? .uploading : .downloading
    }

    // Calculate average speed
    let speeds = transfers.compactMap { $0.bytesPerSecond }
    let averageSpeed =
      speeds.isEmpty
      ? nil
      : TransferSpeed(speeds.map(\.rawValue).reduce(0, +) / Double(speeds.count))

    return TransferProgress(
      totalBytes: hasTotal ? TransferByteCount(totalBytes) : nil,
      transferredBytes: TransferByteCount(transferredBytes),
      phase: phase,
      bytesPerSecond: averageSpeed
    )
  }
}
