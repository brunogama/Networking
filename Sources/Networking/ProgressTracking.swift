import Foundation

/// Progress tracking system using AsyncThrowingStream for real-time progress updates.
/// Provides sophisticated progress monitoring for file transfers, uploads, and downloads.
public struct ProgressTracking: Sendable {
  // MARK: - Progress Stream Types

  /// Comprehensive progress information for a transfer operation
  public struct ProgressUpdate: Sendable, Hashable {
    /// Unique identifier for this transfer
    public let transferId: UUID

    /// Current phase of the transfer
    public let phase: TransferPhase

    /// Total bytes expected (nil if unknown)
    public let totalBytes: Int64?

    /// Bytes transferred so far
    public let transferredBytes: Int64

    /// Current transfer speed in bytes per second
    public let bytesPerSecond: Double?

    /// Estimated time remaining in seconds
    public let estimatedTimeRemaining: TimeInterval?

    /// Progress as a percentage (0.0 to 1.0)
    public var progress: Double {
      guard let total = totalBytes, total > 0 else {
        return phase == .completed ? 1.0 : 0.0
      }
      return min(1.0, max(0.0, Double(transferredBytes) / Double(total)))
    }

    /// Transfer rate in a human-readable format
    public var formattedSpeed: String {
      guard let speed = bytesPerSecond, speed > 0 else {
        return "-- KB/s"
      }

      if speed >= 1_048_576 {  // 1 MB/s
        return String(format: "%.1f MB/s", speed / 1_048_576)
      } else if speed >= 1024 {  // 1 KB/s
        return String(format: "%.1f KB/s", speed / 1024)
      } else {
        return String(format: "%.0f B/s", speed)
      }
    }

    /// Formatted time remaining
    public var formattedTimeRemaining: String {
      guard let timeRemaining = estimatedTimeRemaining else {
        return "-- remaining"
      }

      if timeRemaining >= 3600 {
        let hours = Int(timeRemaining / 3600)
        let minutes = Int((timeRemaining.truncatingRemainder(dividingBy: 3600)) / 60)
        return "\(hours)h \(minutes)m remaining"
      } else if timeRemaining >= 60 {
        let minutes = Int(timeRemaining / 60)
        let seconds = Int(timeRemaining.truncatingRemainder(dividingBy: 60))
        return "\(minutes)m \(seconds)s remaining"
      } else {
        return "\(Int(timeRemaining))s remaining"
      }
    }

    /// Timestamp when this progress update was created
    public let timestamp: Date

    public init(
      transferId: UUID,
      phase: TransferPhase,
      totalBytes: Int64?,
      transferredBytes: Int64,
      bytesPerSecond: Double? = nil,
      estimatedTimeRemaining: TimeInterval? = nil,
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
    case transferNotFound(UUID)
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
    private var activeStreams: [UUID: ProgressStreamHandle] = [:]

    /// Stream handle containing continuation and metadata
    private struct ProgressStreamHandle {
      let transferId: UUID
      let continuation: AsyncThrowingStream<ProgressUpdate, any Error>.Continuation
      var metadata: StreamMetadata
      var isCompleted = false

      struct StreamMetadata {
        let startTime = Date()
        var lastUpdateTime = Date()
        var speedCalculator = TransferSpeedCalculator()
        let totalBytes: Int64?

        init(totalBytes: Int64?) {
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
      for transferId: UUID,
      totalBytes: Int64? = nil
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
      for transferId: UUID,
      transferredBytes: Int64,
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
      for transferId: UUID,
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

      // Clean up after a brief delay to allow final processing
      Task {
        try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 second
        await cleanupStream(transferId)
      }
    }

    /// Cancels a progress stream
    /// - Parameter transferId: Transfer identifier to cancel
    public func cancelProgress(for transferId: UUID) async {
      guard let handle = activeStreams[transferId] else { return }

      handle.continuation.finish(throwing: ProgressError.streamCancelled)
      await cleanupStream(transferId)
    }

    /// Returns active transfer IDs
    public var activeTransferIds: [UUID] {
      Array(activeStreams.keys)
    }

    /// Cleans up completed or cancelled streams
    private func cleanupStream(_ transferId: UUID) async {
      activeStreams.removeValue(forKey: transferId)
    }

    private func calculateEstimatedTime(
      totalBytes: Int64?,
      transferredBytes: Int64,
      speed: Double?
    ) -> TimeInterval? {
      guard let total = totalBytes,
        let currentSpeed = speed,
        currentSpeed > 0,
        transferredBytes < total
      else {
        return nil
      }

      let remainingBytes = total - transferredBytes
      return Double(remainingBytes) / currentSpeed
    }
  }

  // MARK: - Speed Calculation

  /// Calculates transfer speed using a sliding window of measurements
  private struct TransferSpeedCalculator {
    private var measurements: [(timestamp: Date, bytes: Int64)] = []
    private let maxMeasurements = 10
    private let minTimeWindow: TimeInterval = 1.0  // Minimum 1 second for speed calculation

    mutating func addMeasurement(bytes: Int64, timestamp: Date = Date()) {
      measurements.append((timestamp, bytes))

      // Keep only recent measurements
      if measurements.count > maxMeasurements {
        measurements.removeFirst()
      }

      // Remove measurements older than 30 seconds
      let cutoff = timestamp.addingTimeInterval(-30)
      measurements.removeAll { $0.timestamp < cutoff }
    }

    func calculateSpeed() -> Double? {
      guard measurements.count >= 2 else { return nil }

      let first = measurements.first!
      let last = measurements.last!

      let timeInterval = last.timestamp.timeIntervalSince(first.timestamp)
      guard timeInterval >= minTimeWindow else { return nil }

      let bytesTransferred = last.bytes - first.bytes
      guard bytesTransferred > 0 else { return nil }

      return Double(bytesTransferred) / timeInterval
    }
  }

  // MARK: - Progress Monitoring Protocols

  /// Protocol for objects that can monitor transfer progress
  public protocol ProgressMonitor: Sendable {
    /// Called when progress updates are received
    func progressUpdated(_ update: ProgressUpdate) async

    /// Called when a transfer completes successfully
    func transferCompleted(_ transferId: UUID) async

    /// Called when a transfer fails
    func transferFailed(_ transferId: UUID, error: any Error) async
  }

  /// Default implementation of progress monitor that logs to console
  public struct ConsoleProgressMonitor: ProgressMonitor {
    public init() {}

    public func progressUpdated(_ update: ProgressUpdate) async {
      let progressBar = createProgressBar(progress: update.progress)
      print(
        "[\(update.transferId.uuidString.prefix(8))] \(progressBar) \(String(format: "%.1f", update.progress * 100))% - \(update.formattedSpeed)"
      )
    }

    public func transferCompleted(_ transferId: UUID) async {
      print("[\(transferId.uuidString.prefix(8))] ✅ Transfer completed")
    }

    public func transferFailed(_ transferId: UUID, error: any Error) async {
      print("[\(transferId.uuidString.prefix(8))] ❌ Transfer failed: \(error.localizedDescription)")
    }

    private func createProgressBar(progress: Double) -> String {
      let width = 20
      let filledWidth = Int(progress * Double(width))
      let filled = String(repeating: "█", count: filledWidth)
      let empty = String(repeating: "░", count: width - filledWidth)
      return "[\(filled)\(empty)]"
    }
  }

  // MARK: - Batch Progress Tracking

  /// Tracks progress for multiple concurrent transfers
  public actor BatchProgressTracker {
    private let streamManager = ProgressStreamManager()
    private var batchTransfers: [UUID: BatchTransferInfo] = [:]

    private struct BatchTransferInfo {
      let transferId: UUID
      let totalBytes: Int64?
      var transferredBytes: Int64 = 0
      var phase: TransferPhase = .preparing
      var startTime = Date()
    }

    public init() {}

    /// Starts tracking a batch of transfers
    /// - Parameter transferIds: Array of transfer IDs with their expected sizes
    /// - Returns: Dictionary of progress streams for each transfer
    public func startBatchTracking(
      _ transferIds: [(transferId: UUID, totalBytes: Int64?)]
    ) async -> [UUID: AsyncThrowingStream<ProgressUpdate, any Error>] {
      var streams: [UUID: AsyncThrowingStream<ProgressUpdate, any Error>] = [:]

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
      transferId: UUID,
      transferredBytes: Int64,
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
      transferId: UUID,
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

      let totalBytes = activeTransfers.compactMap(\.totalBytes).reduce(0, +)
      let transferredBytes = activeTransfers.map(\.transferredBytes).reduce(0, +)

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
        transferId: UUID(),  // Aggregate ID
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
      case upload(source: URL, destination: URL)
      case download(source: URL, destination: URL)
      case copy(source: URL, destination: URL)
      case move(source: URL, destination: URL)

      public var description: String {
        switch self {
        case .upload(let source, let destination):
          return "Uploading \(source.lastPathComponent) to \(destination.absoluteString)"

        case .download(let source, let destination):
          return "Downloading \(source.lastPathComponent) to \(destination.lastPathComponent)"

        case .copy(let source, let destination):
          return "Copying \(source.lastPathComponent) to \(destination.lastPathComponent)"

        case .move(let source, let destination):
          return "Moving \(source.lastPathComponent) to \(destination.lastPathComponent)"
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
    ) async -> (transferId: UUID, stream: AsyncThrowingStream<ProgressUpdate, any Error>) {
      let transferId = UUID()
      let totalBytes = getTotalBytes(for: operation)

      let stream = await streamManager.createProgressStream(
        for: transferId,
        totalBytes: totalBytes
      )

      return (transferId, stream)
    }

    private static func getTotalBytes(for operation: OperationType) -> Int64? {
      switch operation {
      case .upload(let source, _), .copy(let source, _), .move(let source, _):
        return getFileSize(at: source)

      case .download:
        return nil  // Unknown until we start downloading
      }
    }

    private static func getFileSize(at url: URL) -> Int64? {
      do {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return attributes[.size] as? Int64
      } catch {
        return nil
      }
    }
  }
}

// MARK: - Extensions

extension ProgressTracking.ProgressUpdate: CustomStringConvertible {
  public var description: String {
    let progressPercent = String(format: "%.1f", progress * 100)
    return
      "\(phase) - \(progressPercent)% (\(transferredBytes)/\(totalBytes ?? 0) bytes) - \(formattedSpeed)"
  }
}

extension ProgressTracking.ProgressUpdate: CustomDebugStringConvertible {
  public var debugDescription: String {
    "ProgressUpdate(id: \(transferId), phase: \(phase), progress: \(String(format: "%.1f", progress * 100))%, speed: \(formattedSpeed), eta: \(formattedTimeRemaining))"
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
