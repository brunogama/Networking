import Foundation
import NetworkingCore

/// Progress information for upload or download operations.
public struct TransferProgress: Sendable, Hashable {

  public let totalBytes: TransferByteCount?

  public let transferredBytes: TransferByteCount

  public let phase: TransferPhase

  public var progress: TransferProgressFraction {
    guard let total = totalBytes, total > 0 else {
      return phase == .completed ? 1 : 0
    }
    return TransferProgressFraction(
      min(1.0, max(0.0, Double(transferredBytes.rawValue) / Double(total.rawValue)))
    )
  }

  public let bytesPerSecond: TransferSpeed?

  public var estimatedTimeRemaining: TransferDuration? {
    guard let total = totalBytes,
      let speed = bytesPerSecond,
      speed.rawValue > 0,
      transferredBytes < total
    else {
      return nil
    }

    let remainingBytes = total.rawValue - transferredBytes.rawValue
    return TransferDuration(Double(remainingBytes) / speed.rawValue)
  }

  public let timestamp: Date

  public init(
    totalBytes: TransferByteCount?,
    transferredBytes: TransferByteCount,
    phase: TransferPhase,
    bytesPerSecond: TransferSpeed? = nil,
    timestamp: Date = Date()
  ) {
    self.totalBytes = totalBytes
    self.transferredBytes = transferredBytes
    self.phase = phase
    self.bytesPerSecond = bytesPerSecond
    self.timestamp = timestamp
  }
}

/// A synchronous progress callback that may be invoked from transport or task executors.
public typealias ProgressCallback = @Sendable (TransferProgress) -> Void
