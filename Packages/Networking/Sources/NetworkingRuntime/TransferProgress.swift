import Foundation
import NetworkingCore

/// Progress information for upload or download operations.
public struct TransferProgress: Sendable, Hashable {
  /// Total bytes expected to be transferred (nil if unknown).
  public let totalBytes: TransferByteCount?

  /// Number of bytes transferred so far.
  public let transferredBytes: TransferByteCount

  /// Current transfer phase.
  public let phase: TransferPhase

  /// Progress as a percentage (0.0 to 1.0).
  public var progress: TransferProgressFraction {
    guard let total = totalBytes, total > 0 else {
      return phase == .completed ? 1 : 0
    }
    return TransferProgressFraction(
      min(1.0, max(0.0, Double(transferredBytes.rawValue) / Double(total.rawValue)))
    )
  }

  /// Transfer speed in bytes per second (nil if cannot be calculated).
  public let bytesPerSecond: TransferSpeed?

  /// Estimated time remaining in seconds (nil if cannot be calculated).
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

  /// Timestamp when this progress was recorded.
  public let timestamp: Date

  /// Captures measured byte counts, transfer phase, and optional speed.
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
