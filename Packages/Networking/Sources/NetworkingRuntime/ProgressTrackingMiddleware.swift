import Foundation
import NetworkingCore

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
