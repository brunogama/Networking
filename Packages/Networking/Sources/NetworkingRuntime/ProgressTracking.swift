// swiftlint:disable file_length
import Foundation
import NetworkingCore

// Progress tracking system using AsyncThrowingStream for real-time progress updates.
// Provides sophisticated progress monitoring for file transfers, uploads, and downloads.
// swiftlint:disable:next type_body_length
public struct ProgressTracking: Sendable {
  // MARK: - Progress Stream Types

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

  // MARK: - Progress Stream Management

  /// Manages async progress streams for file transfer operations
  public actor ProgressStreamManager {
    /// Active progress streams indexed by transfer ID
    private var activeStreams: [TransferIdentifier: ProgressStreamHandle] = [:]

    /// Stream handle containing continuation and metadata
    private struct ProgressStreamHandle {
      let transferId: TransferIdentifier
      let continuation: AsyncThrowingStream<ProgressUpdate, any Error>.Continuation
      var metadata: StreamMetadata
      var isCompleted = false

      // swiftlint:disable:next nesting
      struct StreamMetadata {
        let startTime = Date()
        var lastUpdateTime = Date()
        var speedCalculator = TransferSpeedCalculator()
        let totalBytes: TransferByteCount?

        init(totalBytes: TransferByteCount?) {
          self.totalBytes = totalBytes
        }
      }
    }

    public init() {}

    /// Creates a new progress stream for a transfer operation
    /// - Parameters:
    ///   - transferId: Unique identifier for the transfer
    ///   - totalBytes: Expected total bytes (nil if unknown)
    /// - Returns: AsyncThrowingStream for progress updates
    public func createProgressStream(
      for transferId: TransferIdentifier,
      totalBytes: TransferByteCount? = nil
    ) -> AsyncThrowingStream<ProgressUpdate, any Error> {
      AsyncThrowingStream<ProgressUpdate, any Error> { continuation in
        let metadata = ProgressStreamHandle.StreamMetadata(totalBytes: totalBytes)
        let handle = ProgressStreamHandle(
          transferId: transferId,
          continuation: continuation,
          metadata: metadata
        )

        activeStreams[transferId] = handle

        // Send initial progress update
        let initialProgress = ProgressUpdate(
          transferId: transferId,
          phase: .preparing,
          totalBytes: totalBytes,
          transferredBytes: 0
        )

        continuation.yield(initialProgress)

        // Set up cancellation handler
        continuation.onTermination = { [weak self] _ in
          // LIFECYCLE: Fire-and-forget cleanup - safe because:
          // 1. cleanupStream only removes dictionary entry (no external resources)
          // 2. Actor isolation ensures thread safety
          // 3. Short-lived operation (single dictionary mutation)
          // 4. Weak self prevents retain cycles
          Task {
            await self?.cleanupStream(transferId)
          }
        }
      }
    }

    /// Updates progress for an active transfer
    /// - Parameters:
    ///   - transferId: Transfer identifier
    ///   - transferredBytes: Bytes transferred so far
    ///   - phase: Current transfer phase
    public func updateProgress(
      for transferId: TransferIdentifier,
      transferredBytes: TransferByteCount,
      phase: TransferPhase = .downloading
    ) async throws {
      guard var handle = activeStreams[transferId] else {
        throw ProgressError.transferNotFound(transferId)
      }

      guard !handle.isCompleted else {
        throw ProgressError.streamAlreadyCompleted
      }

      let now = Date()
      handle.metadata.speedCalculator.addMeasurement(
        bytes: transferredBytes,
        timestamp: now
      )

      let speed = handle.metadata.speedCalculator.calculateSpeed()
      let estimatedTimeRemaining = calculateEstimatedTime(
        totalBytes: handle.metadata.totalBytes,
        transferredBytes: transferredBytes,
        speed: speed
      )

      let progressUpdate = ProgressUpdate(
        transferId: transferId,
        phase: phase,
        totalBytes: handle.metadata.totalBytes,
        transferredBytes: transferredBytes,
        bytesPerSecond: speed,
        estimatedTimeRemaining: estimatedTimeRemaining,
        timestamp: now
      )

      handle.metadata.lastUpdateTime = now
      activeStreams[transferId] = handle

      handle.continuation.yield(progressUpdate)
    }

    /// Completes a progress stream with final status
    /// - Parameters:
    ///   - transferId: Transfer identifier
    ///   - phase: Final phase (completed or failed)
    ///   - error: Optional error if transfer failed
    public func completeProgress(
      for transferId: TransferIdentifier,
      phase: TransferPhase,
      error: (any Error)? = nil
    ) async {
      guard var handle = activeStreams[transferId] else { return }

      handle.isCompleted = true

      // Send final progress update
      let finalProgress = ProgressUpdate(
        transferId: transferId,
        phase: phase,
        totalBytes: handle.metadata.totalBytes,
        transferredBytes: handle.metadata.totalBytes ?? 0
      )

      handle.continuation.yield(finalProgress)

      // Complete or fail the stream
      if let error = error {
        handle.continuation.finish(throwing: error)
      } else {
        handle.continuation.finish()
      }

      activeStreams[transferId] = handle

      // LIFECYCLE: Fire-and-forget cleanup - safe because:
      // 1. cleanupStream only removes dictionary entry (no external resources)
      // 2. Actor isolation ensures thread safety
      // 3. Bounded delay (0.1s) followed by single dictionary mutation
      // 4. No user-facing impact if delayed cleanup fails
      Task {
        try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 second
        await cleanupStream(transferId)
      }
    }

    /// Cancels a progress stream
    /// - Parameter transferId: Transfer identifier to cancel
    public func cancelProgress(for transferId: TransferIdentifier) async {
      guard let handle = activeStreams[transferId] else { return }

      handle.continuation.finish(throwing: ProgressError.streamCancelled)
      await cleanupStream(transferId)
    }

    /// Returns active transfer IDs
    public var activeTransferIds: [TransferIdentifier] {
      Array(activeStreams.keys)
    }

    /// Cleans up completed or cancelled streams
    private func cleanupStream(_ transferId: TransferIdentifier) async {
      activeStreams.removeValue(forKey: transferId)
    }

    private func calculateEstimatedTime(
      totalBytes: TransferByteCount?,
      transferredBytes: TransferByteCount,
      speed: TransferSpeed?
    ) -> TransferDuration? {
      guard let total = totalBytes,
        let currentSpeed = speed,
        currentSpeed.rawValue > 0,
        transferredBytes < total
      else {
        return nil
      }

      let remainingBytes = total.rawValue - transferredBytes.rawValue
      return TransferDuration(Double(remainingBytes) / currentSpeed.rawValue)
    }

    /// Bridges URLSessionDownloadDelegate progress updates to AsyncThrowingStream.
    ///
    /// Called from delegate callbacks to update progress for download tasks.
    /// Thread-safe via actor isolation.
    ///
    /// - Parameters:
    ///   - transferId: Unique transfer ID (derived from URLSessionTask identifier)
    ///   - bytesWritten: Bytes written in this callback
    ///   - totalBytesWritten: Total bytes written so far
    ///   - totalBytesExpected: Expected total bytes (-1 if unknown)
    public func bridgeDownloadProgress(
      for transferId: TransferIdentifier,
      bytesWritten: TransferByteCount,
      totalBytesWritten: TransferByteCount,
      totalBytesExpected: TransferByteCount
    ) async {
      do {
        try await updateProgress(
          for: transferId,
          transferredBytes: totalBytesWritten,
          phase: .downloading
        )
      } catch {
        writeToStandardError("Progress update failed: \(error)")
      }
    }

    private func writeToStandardError(_ message: String) {
      FileHandle.standardError.write(Data("\(message)\n".utf8))
    }
  }

  // MARK: - Speed Calculation

  /// Calculates transfer speed using a sliding window of measurements
  private struct TransferSpeedCalculator {
    private var measurements: [(timestamp: Date, bytes: TransferByteCount)] = []
    private let maxMeasurements = 10
    private let minTimeWindow: TimeInterval = 1.0  // Minimum 1 second for speed calculation

    mutating func addMeasurement(bytes: TransferByteCount, timestamp: Date = Date()) {
      measurements.append((timestamp, bytes))

      // Keep only recent measurements
      if measurements.count > maxMeasurements {
        measurements.removeFirst()
      }

      // Remove measurements older than 30 seconds
      let cutoff = timestamp.addingTimeInterval(-30)
      measurements.removeAll { $0.timestamp < cutoff }
    }

    func calculateSpeed() -> TransferSpeed? {
      guard measurements.count >= 2 else { return nil }

      let first = measurements.first!
      let last = measurements.last!

      let timeInterval = last.timestamp.timeIntervalSince(first.timestamp)
      guard timeInterval >= minTimeWindow else { return nil }

      let bytesTransferred = last.bytes.rawValue - first.bytes.rawValue
      guard bytesTransferred > 0 else { return nil }

      return TransferSpeed(Double(bytesTransferred) / timeInterval)
    }
  }

  // MARK: - Progress Monitoring Protocols

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

  // MARK: - Batch Progress Tracking

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

  // MARK: - File Operation Progress Tracking

  /// Specialized progress tracker for file operations
  public struct FileOperationProgressTracker: Sendable {
    /// File operation types
    public enum OperationType: Sendable {
      case upload(source: LocalFileURL, destination: RemoteTransferURL)
      case download(source: RemoteTransferURL, destination: LocalFileURL)
      case copy(source: LocalFileURL, destination: LocalFileURL)
      case move(source: LocalFileURL, destination: LocalFileURL)

      public var description: FileOperationDescription {
        switch self {
        case .upload(let source, let destination):
          return FileOperationDescription(
            "Uploading \(source.lastPathComponent) to \(destination.absoluteString)"
          )

        case .download(let source, let destination):
          return FileOperationDescription(
            "Downloading \(source.lastPathComponent) to \(destination.lastPathComponent)"
          )

        case .copy(let source, let destination):
          return FileOperationDescription(
            "Copying \(source.lastPathComponent) to \(destination.lastPathComponent)"
          )

        case .move(let source, let destination):
          return FileOperationDescription(
            "Moving \(source.lastPathComponent) to \(destination.lastPathComponent)"
          )
        }
      }
    }

    /// Creates a progress stream for a file operation
    /// - Parameters:
    ///   - operation: Type of file operation
    ///   - streamManager: Progress stream manager to use
    /// - Returns: Tuple containing transfer ID and progress stream
    public static func trackFileOperation(
      _ operation: OperationType,
      using streamManager: ProgressStreamManager
    ) async -> (
      transferId: TransferIdentifier,
      stream: AsyncThrowingStream<ProgressUpdate, any Error>
    ) {
      let transferId = TransferIdentifier()
      let totalBytes = getTotalBytes(for: operation)

      let stream = await streamManager.createProgressStream(
        for: transferId,
        totalBytes: totalBytes
      )

      return (transferId, stream)
    }

    private static func getTotalBytes(for operation: OperationType) -> TransferByteCount? {
      switch operation {
      case .upload(let source, _), .copy(let source, _), .move(let source, _):
        return getFileSize(at: source)

      case .download:
        return nil  // Unknown until we start downloading
      }
    }

    private static func getFileSize(at url: LocalFileURL) -> TransferByteCount? {
      do {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? Int64 else {
          return nil
        }
        return TransferByteCount(size)
      } catch {
        return nil
      }
    }
  }
}

// MARK: - Extensions

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

// MARK: - Convenience Factory Methods

extension ProgressTracking.ProgressStreamManager {
  /// Creates a stream manager with console monitoring
  public static func withConsoleMonitoring() -> (
    ProgressTracking.ProgressStreamManager, ProgressTracking.ConsoleProgressMonitor
  ) {
    let manager = ProgressTracking.ProgressStreamManager()
    let monitor = ProgressTracking.ConsoleProgressMonitor()
    return (manager, monitor)
  }
}
