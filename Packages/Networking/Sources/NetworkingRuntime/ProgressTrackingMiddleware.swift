// swiftlint:disable file_length
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

/// Middleware that provides upload and download progress tracking capabilities.
public actor ProgressTrackingMiddleware: HTTPRequestMiddleware, HTTPResponseMiddleware {
  // MARK: - Properties

  private let configuration: ProgressTrackingConfiguration
  private var activeTransfers: [UUID: TransferState] = [:]

  // MARK: - Internal State

  private struct TransferState {
    let callback: ProgressCallback?
    var lastUpdateTime = Date()
    var lastUpdateBytes: Int64 = 0
    var startTime = Date()
    var speedCalculator = SpeedCalculator()
    let transferType: TransferType

    enum TransferType {
      case upload
      case download
    }
  }

  // MARK: - Speed Calculation

  private struct SpeedCalculator {
    private var measurements: [(timestamp: Date, bytes: Int64)] = []
    private let maxMeasurements = 10

    mutating func addMeasurement(bytes: Int64, at timestamp: Date = Date()) {
      measurements.append((timestamp, bytes))

      // Keep only recent measurements
      if measurements.count > maxMeasurements {
        measurements.removeFirst()
      }
    }

    func calculateSpeed() -> Double? {
      guard measurements.count >= 2 else { return nil }

      let first = measurements.first!
      let last = measurements.last!

      let timeInterval = last.timestamp.timeIntervalSince(first.timestamp)
      let bytesTransferred = last.bytes - first.bytes

      guard timeInterval > 0 else { return nil }

      return Double(bytesTransferred) / timeInterval
    }
  }

  // MARK: - Initialization

  public init(configuration: ProgressTrackingConfiguration = .default) {
    self.configuration = configuration
  }

  // MARK: - Public API

  /// Registers a progress callback for a specific request.
  /// - Parameters:
  ///   - requestId: The ID of the request to track
  ///   - callback: The callback to invoke with progress updates
  public func setProgressCallback(
    for requestId: HTTPRequestID,
    callback: @escaping ProgressCallback
  ) {
    // This will be set when the request is processed
    Task { self.registerCallback(for: requestId.rawValue, callback: callback) }
  }

  private func registerCallback(for requestId: UUID, callback: @escaping ProgressCallback) {
    // Callback will be stored when request is processed
  }

  // MARK: - HTTPRequestMiddleware

  public func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
    // Check if this request should be tracked
    guard shouldTrackRequest(request) else {
      return request
    }

    // Set up tracking state for upload if applicable
    if hasUploadBody(request) && configuration.trackUploadProgress.rawValue {
      let transferState = TransferState(
        callback: nil,  // Will be set by client
        transferType: .upload
      )
      activeTransfers[request.id.rawValue] = transferState
    }

    return request
  }

  // MARK: - HTTPResponseMiddleware

  public func processResponse(
    _ response: HTTPResponse,
    for request: HTTPRequest
  ) async throws -> HTTPResponse {
    // Handle download progress tracking
    if configuration.trackDownloadProgress.rawValue && shouldTrackDownloadResponse(response) {
      return try await processDownloadResponse(response, for: request)
    }

    // Mark transfer as completed
    await completeTransfer(for: request.id.rawValue)

    return response
  }

  // MARK: - Transfer Management

  private func shouldTrackRequest(_ request: HTTPRequest) -> Bool {
    // Check if request has body for upload tracking
    if configuration.trackUploadProgress.rawValue && hasUploadBody(request) {
      return true
    }

    // Always track GET requests for download progress
    if configuration.trackDownloadProgress.rawValue && request.method == .get {
      return true
    }

    return false
  }

  private func hasUploadBody(_ request: HTTPRequest) -> Bool {
    guard let body = request.body else { return false }
    return Int64(body.count.rawValue) >= configuration.minimumBytesThreshold.rawValue
  }

  private func shouldTrackDownloadResponse(_ response: HTTPResponse) -> Bool {
    guard let contentLength = response.headers["Content-Length"],
      let length = Int64(contentLength)
    else {
      return false
    }

    return length >= configuration.minimumBytesThreshold.rawValue
  }

  private func processDownloadResponse(
    _ response: HTTPResponse,
    for request: HTTPRequest
  ) async throws -> HTTPResponse {
    // For large responses, we would typically stream the response
    // For this implementation, we'll simulate progress based on the response size

    guard let body = response.body else { return response }

    let contentLength = Int64(body.count.rawValue)
    let transferState = TransferState(
      callback: activeTransfers[request.id.rawValue]?.callback,
      transferType: .download
    )

    activeTransfers[request.id.rawValue] = transferState

    // Simulate chunked download progress
    await simulateDownloadProgress(
      requestId: TransferIdentifier(request.id.rawValue),
      totalBytes: TransferByteCount(contentLength),
      data: body.rawValue
    )

    return response
  }

  private func simulateDownloadProgress(
    requestId: TransferIdentifier,
    totalBytes: TransferByteCount,
    data: Data
  ) async {
    guard var transferState = activeTransfers[requestId.rawValue] else { return }

    let chunkSize = min(configuration.defaultChunkSize.rawValue, Int64(data.count))
    var bytesProcessed: Int64 = 0

    // Report initial progress
    await reportProgress(
      for: requestId,
      progress: TransferProgress(
        totalBytes: totalBytes,
        transferredBytes: 0,
        phase: .downloading,
        bytesPerSecond: nil
      )
    )

    // Simulate chunked processing
    while bytesProcessed < totalBytes.rawValue {
      let remainingBytes = totalBytes.rawValue - bytesProcessed
      let currentChunkSize = min(chunkSize, remainingBytes)

      // Simulate processing delay
      // Adjust for realistic timing
      try? await Task.sleep(nanoseconds: UInt64(currentChunkSize * 100))

      bytesProcessed += currentChunkSize
      transferState.speedCalculator.addMeasurement(bytes: bytesProcessed)

      let speed = transferState.speedCalculator.calculateSpeed()

      let progress = TransferProgress(
        totalBytes: totalBytes,
        transferredBytes: TransferByteCount(bytesProcessed),
        phase: bytesProcessed >= totalBytes.rawValue ? .completed : .downloading,
        bytesPerSecond: speed.map { TransferSpeed($0) }
      )

      await reportProgress(for: requestId, progress: progress)

      // Update state
      transferState.lastUpdateBytes = bytesProcessed
      transferState.lastUpdateTime = Date()
      activeTransfers[requestId.rawValue] = transferState
    }
  }

  private func reportProgress(for requestId: TransferIdentifier, progress: TransferProgress) async {
    guard let transferState = activeTransfers[requestId.rawValue],
      let callback = transferState.callback
    else {
      return
    }

    // Check throttling conditions
    let timeSinceLastUpdate = Date().timeIntervalSince(transferState.lastUpdateTime)
    let bytesSinceLastUpdate = progress.transferredBytes.rawValue - transferState.lastUpdateBytes

    let shouldUpdate =
      progress.phase == .completed || progress.phase == .failed
      || timeSinceLastUpdate >= configuration.maxUpdateInterval.rawValue
      || bytesSinceLastUpdate >= configuration.updateIntervalBytes.rawValue

    if shouldUpdate {
      callback(progress)
    }
  }

  private func completeTransfer(for requestId: UUID) async {
    if let transferState = activeTransfers[requestId] {
      let finalProgress = TransferProgress(
        totalBytes: nil,
        transferredBytes: 0,
        phase: .completed
      )

      if let callback = transferState.callback {
        callback(finalProgress)
      }
    }

    activeTransfers.removeValue(forKey: requestId)
  }

  private func failTransfer(for requestId: UUID, error: any Error) async {
    if let transferState = activeTransfers[requestId] {
      let failedProgress = TransferProgress(
        totalBytes: nil,
        transferredBytes: TransferByteCount(transferState.lastUpdateBytes),
        phase: .failed
      )

      if let callback = transferState.callback {
        callback(failedProgress)
      }
    }

    activeTransfers.removeValue(forKey: requestId)
  }
}

// MARK: - Resumable Transfer Support

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

// MARK: - Chunked Transfer Support

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

// MARK: - Extensions

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

// MARK: - Progress Reporting Utilities

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
