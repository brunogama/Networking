import Foundation
import NetworkingCore

/// Protocol for resumable transfer operations.
public protocol ResumableTransfer: Sendable {
  /// The unique identifier for this transfer
  var transferId: TransferIdentifier { get }

  /// The total expected bytes for the transfer
  var totalBytes: TransferByteCount? { get }

  /// The number of bytes already transferred
  var resumeOffset: TransferOffset { get }

  /// Whether this transfer can be resumed
  var canResume: ResumableTransferFlag { get }

  /// Resume data that can be used to continue the transfer
  var resumeData: TransferResumeData? { get }
}

/// Default implementation of resumable transfer.
public struct DefaultResumableTransfer: ResumableTransfer {
  public let transferId: TransferIdentifier
  public let totalBytes: TransferByteCount?
  public let resumeOffset: TransferOffset
  public let canResume: ResumableTransferFlag
  public let resumeData: TransferResumeData?

  public init(
    transferId: TransferIdentifier = TransferIdentifier(),
    totalBytes: TransferByteCount? = nil,
    resumeOffset: TransferOffset = 0,
    canResume: ResumableTransferFlag = true,
    resumeData: TransferResumeData? = nil
  ) {
    self.transferId = transferId
    self.totalBytes = totalBytes
    self.resumeOffset = resumeOffset
    self.canResume = canResume
    self.resumeData = resumeData
  }
}

/// Configuration for chunked transfer operations.
public struct ChunkedTransferConfiguration: Sendable {
  /// Size of each chunk in bytes
  public let chunkSize: ChunkSize

  /// Maximum number of concurrent chunks
  public let maxConcurrentChunks: ChunkCount

  /// Retry configuration for failed chunks
  public let retryConfiguration: ChunkRetryConfiguration

  public init(
    chunkSize: ChunkSize = 65_536,  // 64KB
    maxConcurrentChunks: ChunkCount = 4,
    retryConfiguration: ChunkRetryConfiguration = .default
  ) {
    self.chunkSize = chunkSize
    self.maxConcurrentChunks = maxConcurrentChunks
    self.retryConfiguration = retryConfiguration
  }

  public static let `default` = Self()
}

/// Retry configuration for chunk operations.
public struct ChunkRetryConfiguration: Sendable {
  /// Maximum number of retry attempts per chunk
  public let maxRetries: TransferRetryCount

  /// Base delay between retries
  public let baseDelay: RetryDelay

  /// Backoff multiplier for exponential backoff
  public let backoffMultiplier: BackoffMultiplier

  public init(
    maxRetries: TransferRetryCount = 3,
    baseDelay: RetryDelay = 1.0,
    backoffMultiplier: BackoffMultiplier = 2.0
  ) {
    self.maxRetries = maxRetries
    self.baseDelay = baseDelay
    self.backoffMultiplier = backoffMultiplier
  }

  public static let `default` = Self()
}

extension ProgressTrackingMiddleware {
  /// Creates a middleware with a progress callback for a specific request.
  /// - Parameters:
  ///   - requestId: The request ID to track
  ///   - callback: The progress callback
  ///   - configuration: Optional custom configuration
  /// - Returns: Configured middleware instance
  public static func withCallback(
    for requestId: HTTPRequestID,
    callback: @escaping ProgressCallback,
    configuration: ProgressTrackingConfiguration = .default
  ) -> ProgressTrackingMiddleware {
    let middleware = ProgressTrackingMiddleware(configuration: configuration)
    Task {
      await middleware.setProgressCallback(for: requestId, callback: callback)
    }
    return middleware
  }
}

/// Utility for aggregating progress from multiple concurrent transfers.
public actor ProgressAggregator {
  private var activeTransfers: [TransferIdentifier: TransferProgress] = [:]
  private let callback: ProgressCallback

  public init(callback: @escaping ProgressCallback) {
    self.callback = callback
  }

  /// Updates progress for a specific transfer.
  /// - Parameters:
  ///   - transferId: The transfer identifier
  ///   - progress: The current progress
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
