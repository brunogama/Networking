import Foundation
import NetworkingCore

extension ProgressTracking {
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
}

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
