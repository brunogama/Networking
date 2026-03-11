import Foundation
import NetworkingCore

/// Represents the different phases of a network transfer.
public enum TransferPhase: Sendable, Hashable {
  case preparing
  case uploading
  case downloading
  case completed
  case failed
}

/// Progress information for upload or download operations.
public struct TransferProgress: Sendable, Hashable {
  /// Total bytes expected to be transferred (nil if unknown)
  public let totalBytes: TransferByteCount?

  /// Number of bytes transferred so far
  public let transferredBytes: TransferByteCount

  /// Current transfer phase
  public let phase: TransferPhase

  /// Progress as a percentage (0.0 to 1.0)
  public var progress: TransferProgressFraction {
    guard let total = totalBytes, total > 0 else {
      return phase == .completed ? 1 : 0
    }
    return TransferProgressFraction(
      min(1.0, max(0.0, Double(transferredBytes.rawValue) / Double(total.rawValue)))
    )
  }

  /// Transfer speed in bytes per second (nil if cannot be calculated)
  public let bytesPerSecond: TransferSpeed?

  /// Estimated time remaining in seconds (nil if cannot be calculated)
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

  /// Timestamp when this progress was recorded
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

/// Type alias for progress callback closure.
public typealias ProgressCallback = @Sendable (TransferProgress) -> Void

/// Configuration for progress tracking middleware.
public struct ProgressTrackingConfiguration: Sendable {
  /// Whether to track upload progress
  public let trackUploadProgress: UploadProgressTrackingFlag

  /// Whether to track download progress
  public let trackDownloadProgress: DownloadProgressTrackingFlag

  /// Minimum bytes threshold to start tracking (avoids overhead for small transfers)
  public let minimumBytesThreshold: TransferByteCount

  /// Progress update interval in bytes (updates are throttled to avoid excessive callbacks)
  public let updateIntervalBytes: TransferByteCount

  /// Maximum time interval between progress updates (ensures regular updates)
  public let maxUpdateInterval: TransferDuration

  /// Whether to enable chunked transfer support
  public let enableChunkedTransfer: ChunkedTransferSupportFlag

  /// Default chunk size for chunked transfers
  public let defaultChunkSize: ChunkSize

  public init(
    trackUploadProgress: UploadProgressTrackingFlag = true,
    trackDownloadProgress: DownloadProgressTrackingFlag = true,
    minimumBytesThreshold: TransferByteCount = 1024,  // 1KB
    updateIntervalBytes: TransferByteCount = 8192,  // 8KB
    maxUpdateInterval: TransferDuration = 0.1,  // 100ms
    enableChunkedTransfer: ChunkedTransferSupportFlag = true,
    defaultChunkSize: ChunkSize = 65_536  // 64KB
  ) {
    self.trackUploadProgress = trackUploadProgress
    self.trackDownloadProgress = trackDownloadProgress
    self.minimumBytesThreshold = minimumBytesThreshold
    self.updateIntervalBytes = updateIntervalBytes
    self.maxUpdateInterval = maxUpdateInterval
    self.enableChunkedTransfer = enableChunkedTransfer
    self.defaultChunkSize = defaultChunkSize
  }

  public static let `default` = Self()
}
