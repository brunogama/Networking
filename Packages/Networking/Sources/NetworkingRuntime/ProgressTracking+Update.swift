import Foundation
import NetworkingCore

extension ProgressTracking {
  /// Comprehensive progress information for a transfer operation
  public struct ProgressUpdate: Sendable, Hashable {
    /// Unique identifier for this transfer
    public let transferId: TransferIdentifier

    /// Current phase of the transfer
    public let phase: TransferPhase

    /// Total bytes expected (nil if unknown)
    public let totalBytes: TransferByteCount?

    /// Bytes transferred so far
    public let transferredBytes: TransferByteCount

    /// Current transfer speed in bytes per second
    public let bytesPerSecond: TransferSpeed?

    /// Estimated time remaining in seconds
    public let estimatedTimeRemaining: TransferDuration?

    /// Progress as a percentage (0.0 to 1.0)
    public var progress: TransferProgressFraction {
      guard let total = totalBytes, total > 0 else {
        return phase == .completed ? 1.0 : 0.0
      }
      return TransferProgressFraction(
        min(
          1.0,
          max(0.0, Double(transferredBytes.rawValue) / Double(total.rawValue))
        )
      )
    }

    /// Transfer rate in a human-readable format
    public var formattedSpeed: TransferSpeedText {
      guard let speed = bytesPerSecond, speed > 0 else {
        return "-- KB/s"
      }

      if speed.rawValue >= 1_048_576 {  // 1 MB/s
        return TransferSpeedText(String(format: "%.1f MB/s", speed.rawValue / 1_048_576))
      } else if speed.rawValue >= 1024 {  // 1 KB/s
        return TransferSpeedText(String(format: "%.1f KB/s", speed.rawValue / 1024))
      } else {
        return TransferSpeedText(String(format: "%.0f B/s", speed.rawValue))
      }
    }

    /// Formatted time remaining
    public var formattedTimeRemaining: TransferTimeRemainingText {
      guard let timeRemaining = estimatedTimeRemaining else {
        return "-- remaining"
      }

      if timeRemaining.rawValue >= 3600 {
        let hours = Int(timeRemaining.rawValue / 3600)
        let minutes = Int((timeRemaining.rawValue.truncatingRemainder(dividingBy: 3600)) / 60)
        return TransferTimeRemainingText("\(hours)h \(minutes)m remaining")
      } else if timeRemaining.rawValue >= 60 {
        let minutes = Int(timeRemaining.rawValue / 60)
        let seconds = Int(timeRemaining.rawValue.truncatingRemainder(dividingBy: 60))
        return TransferTimeRemainingText("\(minutes)m \(seconds)s remaining")
      } else {
        return TransferTimeRemainingText("\(Int(timeRemaining.rawValue))s remaining")
      }
    }

    /// Timestamp when this progress update was created
    public let timestamp: Date

    public init(
      transferId: TransferIdentifier,
      phase: TransferPhase,
      totalBytes: TransferByteCount?,
      transferredBytes: TransferByteCount,
      bytesPerSecond: TransferSpeed? = nil,
      estimatedTimeRemaining: TransferDuration? = nil,
      timestamp: Date = Date()
    ) {
      self.transferId = transferId
      self.phase = phase
      self.totalBytes = totalBytes
      self.transferredBytes = transferredBytes
      self.bytesPerSecond = bytesPerSecond
      self.estimatedTimeRemaining = estimatedTimeRemaining
      self.timestamp = timestamp
    }
  }

  /// Error conditions that can occur during progress tracking
  public enum ProgressError: Error, LocalizedError {
    case streamCancelled
    case transferNotFound(TransferIdentifier)
    case invalidProgressData
    case streamAlreadyCompleted

    public var errorDescription: String? {
      switch self {
      case .streamCancelled:
        return "Progress stream was cancelled"

      case .transferNotFound(let id):
        return "Transfer with ID \(id) not found"

      case .invalidProgressData:
        return "Invalid progress data received"

      case .streamAlreadyCompleted:
        return "Progress stream has already completed"
      }
    }
  }
}

extension ProgressTracking.ProgressUpdate: CustomStringConvertible {
  public var description: String {
    let summary = TransferProgressSummaryText(
      "\(phase) - \(String(format: "%.1f", progress.rawValue * 100))% (\(transferredBytes)/\(totalBytes ?? 0) bytes) - \(formattedSpeed)"
    )
    return summary.rawValue
  }
}

extension ProgressTracking.ProgressUpdate: CustomDebugStringConvertible {
  public var debugDescription: String {
    "ProgressUpdate(id: \(transferId), phase: \(phase), progress: \(String(format: "%.1f", progress.rawValue * 100))%, speed: \(formattedSpeed), eta: \(formattedTimeRemaining))"
  }
}
