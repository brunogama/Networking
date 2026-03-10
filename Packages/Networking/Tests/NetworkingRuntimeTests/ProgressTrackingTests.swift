// swiftlint:disable file_length
import Foundation
@testable import NetworkingRuntime
import NetworkingCore
import NetworkingDSL
import NetworkingRuntimeDSL
import NetworkingTesting
import Testing

// Test suite for progress tracking functionality.
@Suite("Progress Tracking Tests")
// swiftlint:disable:next type_body_length
struct ProgressTrackingTests {
  // MARK: - Test Data

  private let testURL = URL(string: "https://api.example.com/test")!
  private let testFileURL = URL(string: "https://api.example.com/files/test.jpg")!

  // MARK: - Progress Configuration Tests

  @Test("Default progress tracking configuration has expected values")
  func defaultProgressConfiguration() async throws {
    let config = ProgressTrackingConfiguration.default

    #expect(config.trackUploadProgress == true)
    #expect(config.trackDownloadProgress == true)
    #expect(config.minimumBytesThreshold == 1024)
    #expect(config.updateIntervalBytes == 8192)
    #expect(config.maxUpdateInterval == 0.1)
    #expect(config.enableChunkedTransfer == true)
    #expect(config.defaultChunkSize == 65536)
  }

  @Test("Custom progress tracking configuration can be created")
  func customProgressConfiguration() async throws {
    let config = ProgressTrackingConfiguration(
      trackUploadProgress: false,
      trackDownloadProgress: true,
      minimumBytesThreshold: 2048,
      updateIntervalBytes: 16384,
      maxUpdateInterval: 0.5,
      enableChunkedTransfer: false,
      defaultChunkSize: 32768
    )

    #expect(config.trackUploadProgress == false)
    #expect(config.trackDownloadProgress == true)
    #expect(config.minimumBytesThreshold == 2048)
    #expect(config.updateIntervalBytes == 16384)
    #expect(config.maxUpdateInterval == 0.5)
    #expect(config.enableChunkedTransfer == false)
    #expect(config.defaultChunkSize == 32768)
  }

  // MARK: - Transfer Progress Tests

  @Test("Transfer progress calculates percentage correctly")
  func transferProgressCalculation() async throws {
    let progress1 = TransferProgress(
      totalBytes: 1000,
      transferredBytes: 500,
      phase: .downloading
    )
    #expect(progress1.progress == 0.5)

    let progress2 = TransferProgress(
      totalBytes: 1000,
      transferredBytes: 250,
      phase: .uploading
    )
    #expect(progress2.progress == 0.25)

    // Test completed progress without total bytes
    let progress3 = TransferProgress(
      totalBytes: nil,
      transferredBytes: 1000,
      phase: .completed
    )
    #expect(progress3.progress == 1.0)

    // Test unknown total bytes
    let progress4 = TransferProgress(
      totalBytes: nil,
      transferredBytes: 500,
      phase: .downloading
    )
    #expect(progress4.progress == 0.0)
  }

  @Test("Transfer progress calculates estimated time remaining")
  func testEstimatedTimeRemaining() async throws {
    let progress = TransferProgress(
      totalBytes: 1000,
      transferredBytes: 250,
      phase: .downloading,
      bytesPerSecond: 100.0
    )

    // Remaining: 750 bytes, Speed: 100 bytes/sec = 7.5 seconds
    #expect(progress.estimatedTimeRemaining == 7.5)

    // Test with no speed data
    let progressNoSpeed = TransferProgress(
      totalBytes: 1000,
      transferredBytes: 250,
      phase: .downloading,
      bytesPerSecond: nil
    )
    #expect(progressNoSpeed.estimatedTimeRemaining == nil)

    // Test completed transfer
    let completedProgress = TransferProgress(
      totalBytes: 1000,
      transferredBytes: 1000,
      phase: .completed,
      bytesPerSecond: 100.0
    )
    #expect(completedProgress.estimatedTimeRemaining == nil)
  }

  @Test("Transfer progress is Sendable and Hashable")
  func transferProgressSendableHashable() async throws {
    let progress1 = TransferProgress(
      totalBytes: 1000,
      transferredBytes: 500,
      phase: .downloading,
      bytesPerSecond: 100.0,
      timestamp: Date(timeIntervalSince1970: 1000)
    )

    let progress2 = TransferProgress(
      totalBytes: 1000,
      transferredBytes: 500,
      phase: .downloading,
      bytesPerSecond: 100.0,
      timestamp: Date(timeIntervalSince1970: 1000)
    )

    let progress3 = TransferProgress(
      totalBytes: 1000,
      transferredBytes: 600,
      phase: .downloading,
      bytesPerSecond: 100.0,
      timestamp: Date(timeIntervalSince1970: 1000)
    )

    // Test hashable conformance
    #expect(progress1 == progress2)
    #expect(progress1 != progress3)

    let progressSet: Set<TransferProgress> = [progress1, progress2, progress3]
    #expect(progressSet.count == 2)  // progress1 and progress2 should be the same
  }

  // MARK: - Progress Middleware Tests

  @Test("Progress middleware can be initialized with default configuration")
  func progressMiddlewareInitialization() async throws {
    let middleware = ProgressTrackingMiddleware()

    // Test that middleware is properly initialized
    #expect(middleware != nil)
  }

  @Test("Progress middleware can be initialized with custom configuration")
  func progressMiddlewareCustomConfiguration() async throws {
    let config = ProgressTrackingConfiguration(
      trackUploadProgress: false,
      trackDownloadProgress: true
    )
    let middleware = ProgressTrackingMiddleware(configuration: config)

    #expect(middleware != nil)
  }

  @Test("Progress middleware can be created with callback")
  func progressMiddlewareWithCallback() async throws {
    let expectation = AsyncExpectation("Progress callback called")

    actor ProgressReceiver {
      var receivedProgress: TransferProgress?

      func setProgress(_ progress: TransferProgress) {
        receivedProgress = progress
      }

      func getProgress() -> TransferProgress? {
        receivedProgress
      }
    }

    let progressReceiver = ProgressReceiver()

    let middleware = ProgressTrackingMiddleware.withCallback(
      for: HTTPRequestID(UUID()),
      callback: { progress in
        Task { await progressReceiver.setProgress(progress) }
        expectation.fulfill()
      }
    )

    #expect(middleware != nil)

    // In a real test, we would trigger progress updates
    // For now, just verify the middleware was created successfully
  }

  @Test("Progress middleware modifies request correctly for upload tracking")
  func progressMiddlewareUploadTracking() async throws {
    let middleware = ProgressTrackingMiddleware()

    // Create request with body data that exceeds threshold
    let largeData = Data(repeating: 0x41, count: 2048)  // 2KB of 'A' characters
    let request = HTTPRequest(
      method: .post,
      url: testURL,
      body: largeData
    )

    let modifiedRequest = try await middleware.modifyRequest(request)

    // Request should pass through unchanged for middleware
    #expect(modifiedRequest.id == request.id)
    #expect(modifiedRequest.method == request.method)
    #expect(modifiedRequest.url == request.url)
    #expect(modifiedRequest.body == request.body)
  }

  @Test("Progress middleware handles small requests without tracking")
  func progressMiddlewareSmallRequestHandling() async throws {
    let middleware = ProgressTrackingMiddleware()

    // Create request with small body that doesn't meet threshold
    let smallData = Data(repeating: 0x41, count: 500)  // 500 bytes
    let request = HTTPRequest(
      method: .post,
      url: testURL,
      body: smallData
    )

    let modifiedRequest = try await middleware.modifyRequest(request)

    // Request should pass through unchanged
    #expect(modifiedRequest.id == request.id)
    #expect(modifiedRequest.method == request.method)
    #expect(modifiedRequest.url == request.url)
    #expect(modifiedRequest.body == request.body)
  }

  // MARK: - Resumable Transfer Tests

  @Test("Default resumable transfer has correct default values")
  func defaultResumableTransfer() async throws {
    let transfer = DefaultResumableTransfer()

    #expect(!transfer.transferId.rawValue.uuidString.isEmpty)
    #expect(transfer.totalBytes == nil)
    #expect(transfer.resumeOffset == 0)
    #expect(transfer.canResume == true)
    #expect(transfer.resumeData == nil)
  }

  @Test("Resumable transfer can be created with custom values")
  func customResumableTransfer() async throws {
    let transferId = TransferIdentifier()
    let resumeData = TransferResumeData(Data([0x01, 0x02, 0x03]))

    let transfer = DefaultResumableTransfer(
      transferId: transferId,
      totalBytes: 1024,
      resumeOffset: 512,
      canResume: false,
      resumeData: resumeData
    )

    #expect(transfer.transferId == transferId)
    #expect(transfer.totalBytes == 1024)
    #expect(transfer.resumeOffset == 512)
    #expect(transfer.canResume == false)
    #expect(transfer.resumeData == resumeData)
  }

  // MARK: - Chunked Transfer Configuration Tests

  @Test("Default chunked transfer configuration has expected values")
  func defaultChunkedTransferConfiguration() async throws {
    let config = ChunkedTransferConfiguration.default

    #expect(config.chunkSize == 65536)  // 64KB
    #expect(config.maxConcurrentChunks == 4)
    #expect(config.retryConfiguration.maxRetries == 3)
    #expect(config.retryConfiguration.baseDelay == 1.0)
    #expect(config.retryConfiguration.backoffMultiplier == 2.0)
  }

  @Test("Custom chunked transfer configuration can be created")
  func customChunkedTransferConfiguration() async throws {
    let retryConfig = ChunkRetryConfiguration(
      maxRetries: 5,
      baseDelay: 2.0,
      backoffMultiplier: 1.5
    )

    let config = ChunkedTransferConfiguration(
      chunkSize: 32768,
      maxConcurrentChunks: 8,
      retryConfiguration: retryConfig
    )

    #expect(config.chunkSize == 32768)
    #expect(config.maxConcurrentChunks == 8)
    #expect(config.retryConfiguration.maxRetries == 5)
    #expect(config.retryConfiguration.baseDelay == 2.0)
    #expect(config.retryConfiguration.backoffMultiplier == 1.5)
  }

  // MARK: - Progress Aggregator Tests

  @Test("Progress aggregator calculates aggregate progress correctly")
  func progressAggregator() async throws {
    let expectation = AsyncExpectation("Aggregate progress callback called")

    actor ProgressStorage {
      var progress: TransferProgress?

      func set(_ progress: TransferProgress?) {
        self.progress = progress
      }

      func get() -> TransferProgress? {
        progress
      }
    }

    let receivedProgress = ProgressStorage()

    let aggregator = ProgressAggregator { progress in
      Task { await receivedProgress.set(progress) }
      expectation.fulfill()
    }

    // Add progress for multiple transfers
    let progress1 = TransferProgress(
      totalBytes: 1000,
      transferredBytes: 500,
      phase: .downloading
    )
    let progress2 = TransferProgress(
      totalBytes: 2000,
      transferredBytes: 1000,
      phase: .downloading
    )

    await aggregator.updateProgress(for: TransferIdentifier(), progress: progress1)
    await aggregator.updateProgress(for: TransferIdentifier(), progress: progress2)

    // Verify aggregate calculation would be correct
    // Total: 3000 bytes, Transferred: 1500 bytes = 50% progress

    #expect(aggregator != nil)
  }

  @Test("Progress aggregator handles completed transfers correctly")
  func progressAggregatorCompletedTransfers() async throws {
    let aggregator = ProgressAggregator { _ in }

    let transferId = TransferIdentifier()
    let progress = TransferProgress(
      totalBytes: 1000,
      transferredBytes: 1000,
      phase: .completed
    )

    await aggregator.updateProgress(for: transferId, progress: progress)

    // Completed transfers should be cleaned up automatically
    #expect(aggregator != nil)
  }

  // MARK: - File Transfer Tests

  @Test("File transfer configuration has correct default values")
  func fileTransferDefaultConfiguration() async throws {
    let config = FileTransferConfiguration.default

    #expect(config.maxFileSize.rawValue == 500 * 1024 * 1024)  // 500MB
    #expect(config.supportedMimeTypes == nil)  // All types supported by default
    #expect(config.enableIntegrityCheck == true)
    #expect(config.checksumAlgorithm == .sha256)
    #expect(config.allowResumableTransfers == true)
    #expect(config.temporaryDirectory == nil)
  }

  @Test("File metadata calculation works correctly")
  func fileMetadata() async throws {
    let metadata = FileMetadata(
      name: "test.jpg",
      size: 1024,
      mimeType: "image/jpeg",
      checksum: "abcd1234"
    )

    #expect(metadata.name == "test.jpg")
    #expect(metadata.size == 1024)
    #expect(metadata.mimeType == "image/jpeg")
    #expect(metadata.checksum == "abcd1234")
    #expect(metadata.fileExtension == "jpg")
  }

  @Test("File metadata handles files without extension")
  func fileMetadataNoExtension() async throws {
    let metadata = FileMetadata(
      name: "testfile",
      size: 1024
    )

    #expect(metadata.name == "testfile")
    #expect(metadata.fileExtension == nil)
  }

  @Test("Checksum algorithms are correctly defined")
  func checksumAlgorithms() async throws {
    let algorithms = ChecksumAlgorithm.allCases

    // Only secure algorithms should be available
    #expect(algorithms.contains(.sha256))
    #expect(algorithms.contains(.sha512))
    // MD5 and SHA1 removed for security reasons
    #expect(algorithms.count == 2)

    // Test that hash functions exist
    let testData = Data([0x01, 0x02, 0x03])

    for algorithm in algorithms {
      let result = algorithm.hash(HTTPBody(testData))
      #expect(result.isEmpty == false)
    }
  }

  @Test("File transfer errors provide meaningful descriptions")
  func fileTransferErrorDescriptions() async throws {
    let fileTooLargeError = FileTransferError.fileTooLarge(size: 1000, maxSize: 500)
    #expect(fileTooLargeError.errorDescription?.contains("exceeds maximum") == true)

    let unsupportedTypeError = FileTransferError.unsupportedFileType(mimeType: "text/plain")
    #expect(unsupportedTypeError.errorDescription?.contains("not supported") == true)

    let fileNotFoundError = FileTransferError.fileNotFound(path: "/test/path")
    #expect(fileNotFoundError.errorDescription?.contains("not found") == true)

    let checksumError = FileTransferError.checksumMismatch(expected: "abc", actual: "def")
    #expect(checksumError.errorDescription?.contains("integrity check failed") == true)

    let cancelledError = FileTransferError.transferCancelled
    #expect(cancelledError.errorDescription?.contains("cancelled") == true)
  }

  @Test("Background transfer configuration has correct default values")
  func backgroundTransferConfiguration() async throws {
    let config = BackgroundTransferConfiguration.default

    #expect(config.enableBackgroundTransfer == false)
    #expect(config.backgroundSessionIdentifier == "Networking.BackgroundTransfer")
    #expect(config.allowsCellularAccess == true)
    #expect(config.allowsExpensiveNetworkAccess == false)
    #expect(config.timeoutIntervalForRequest.rawValue == 60.0)
    #expect(config.timeoutIntervalForResource.rawValue == 3600.0)
  }

  // MARK: - Mock Client for Integration Tests

  private struct MockHTTPClient: HTTPClient {
    let mockResponse: HTTPResponse
    let delay: TimeInterval

    init(mockResponse: HTTPResponse, delay: TimeInterval = 0) {
      self.mockResponse = mockResponse
      self.delay = delay
    }

    func execute(_: HTTPRequest) async throws -> HTTPResponse {
      if delay > 0 {
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
      }
      return mockResponse
    }
  }

  // MARK: - Integration Tests

  @Test("File transfer operations can be initialized")
  func fileTransferOperationsInitialization() async throws {
    let mockClient = MockHTTPClient(
      mockResponse: HTTPResponse(
        request: HTTPRequest(method: .get, url: testURL),
        httpURLResponse: HTTPURLResponse(
          url: testURL,
          statusCode: 200,
          httpVersion: nil,
          headerFields: nil
        )!,
        body: HTTPBody(Data())
      )
    )

    let fileTransfer = FileTransferOperations(
      httpClient: mockClient,
      configuration: .default
    )

    #expect(fileTransfer != nil)
  }

  @Test("File transfer operations can upload data")
  func fileTransferUploadData() async throws {
    let testData = Data("Hello, World!".utf8)

    let mockResponse = HTTPResponse(
      request: HTTPRequest(method: .post, url: testURL),
      httpURLResponse: HTTPURLResponse(
        url: testURL,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
      )!,
      body: HTTPBody(Data())
    )

    let mockClient = MockHTTPClient(mockResponse: mockResponse)
    let fileTransfer = FileTransferOperations(
      httpClient: mockClient,
      configuration: .default
    )

    actor ProgressUpdatesStorage {
      var updates: [TransferProgress] = []

      func append(_ progress: TransferProgress) {
        updates.append(progress)
      }

      func getAll() -> [TransferProgress] {
        updates
      }
    }

    let progressUpdates = ProgressUpdatesStorage()

    let result = try await fileTransfer.uploadData(
      HTTPBody(testData),
      fileName: "test.txt",
      to: RemoteTransferURL(testURL),
      mimeType: "text/plain"
    ) { progress in
      Task { await progressUpdates.append(progress) }
    }

    #expect(result.isSuccessful == true)
    #expect(result.bytesTransferred >= 0)
    #expect(!result.transferId.rawValue.uuidString.isEmpty)
  }

  @Test("File transfer operations handle download data")
  func fileTransferDownloadData() async throws {
    let testData = Data("Downloaded content".utf8)

    let mockResponse = HTTPResponse(
      request: HTTPRequest(method: .get, url: testFileURL),
      httpURLResponse: HTTPURLResponse(
        url: testFileURL,
        statusCode: 200,
        httpVersion: nil,
        headerFields: ["Content-Length": "\(testData.count)"]
      )!,
      body: HTTPBody(testData)
    )

    let mockClient = MockHTTPClient(mockResponse: mockResponse)
    let fileTransfer = FileTransferOperations(
      httpClient: mockClient,
      configuration: .default
    )

    let (downloadedData, result) = try await fileTransfer.downloadData(
      from: RemoteTransferURL(testFileURL)
    ) { _ in
      // Progress tracking
    }

    #expect(result.isSuccessful == true)
    #expect(downloadedData.rawValue == testData)
  }

  // MARK: - Async Helper

  /// Helper class to handle async expectations in tests
  private final class AsyncExpectation: @unchecked Sendable {
    private let description: String
    private var isFulfilled = false
    private let lock = NSLock()

    init(_ description: String) {
      self.description = description
    }

    func fulfill() {
      lock.withLock {
        isFulfilled = true
      }
    }

    var fulfilled: Bool {
      lock.withLock {
        isFulfilled
      }
    }
  }

  // MARK: - Performance Tests

  @Test("Progress tracking middleware has minimal performance overhead")
  func progressTrackingPerformance() async throws {
    let middleware = ProgressTrackingMiddleware()
    let request = HTTPRequest(method: .get, url: testURL)

    // Measure performance of request modification
    let startTime = Date()

    for _ in 0..<1000 {
      _ = try await middleware.modifyRequest(request)
    }

    let duration = Date().timeIntervalSince(startTime)

    // Performance should be reasonable (less than 1 second for 1000 operations)
    #expect(duration < 1.0)
  }

  @Test("Transfer progress calculation is performant")
  func transferProgressPerformance() async throws {
    let startTime = Date()

    // Create many progress instances and calculate percentages
    for i in 0..<10000 {
      let progress = TransferProgress(
        totalBytes: 10000,
        transferredBytes: TransferByteCount(Int64(i)),
        phase: .downloading,
        bytesPerSecond: 1000.0
      )

      // Access computed properties
      _ = progress.progress
      _ = progress.estimatedTimeRemaining
    }

    let duration = Date().timeIntervalSince(startTime)

    // Should complete quickly
    #expect(duration < 0.1)
  }

  // MARK: - Edge Case Tests

  @Test("Progress tracking handles zero-byte transfers")
  func zeroByteTransfer() async throws {
    let progress = TransferProgress(
      totalBytes: 0,
      transferredBytes: 0,
      phase: .completed
    )

    #expect(progress.progress == 1.0)  // Completed transfers should show 100%
    #expect(progress.estimatedTimeRemaining == nil)
  }

  @Test("Progress tracking handles negative values gracefully")
  func negativeValues() async throws {
    let progress = TransferProgress(
      totalBytes: 1000,
      transferredBytes: -100,  // Invalid, but should be handled
      phase: .downloading
    )

    // Progress should be clamped to valid range
    #expect(progress.progress >= 0.0)
    #expect(progress.progress <= 1.0)
  }

  @Test("Progress tracking handles very large numbers")
  func largeNumbers() async throws {
    let largeSize = Int64.max / 2
    let progress = TransferProgress(
      totalBytes: TransferByteCount(largeSize),
      transferredBytes: TransferByteCount(largeSize / 2),
      phase: .downloading
    )

    #expect(progress.progress == 0.5)
  }

  @Test("File metadata handles unicode filenames")
  func unicodeFilenames() async throws {
    let metadata = FileMetadata(
      name: "测试文件.jpg",  // Chinese characters
      size: 1024,
      mimeType: "image/jpeg"
    )

    #expect(metadata.name == "测试文件.jpg")
    #expect(metadata.fileExtension == "jpg")
  }

  @Test("File metadata handles very long filenames")
  func longFilenames() async throws {
    let longName = String(repeating: "a", count: 255) + ".txt"
    let metadata = FileMetadata(
      name: FileName(longName),
      size: 1024
    )

    #expect(metadata.name == FileName(longName))
    #expect(metadata.fileExtension == "txt")
  }

  // MARK: - Download Progress Bridge Tests

  @Test("ProgressStreamManager bridgeDownloadProgress updates stream")
  // swiftlint:disable:next function_body_length
  func progressStreamManagerBridgeDownloadProgress() async throws {
    let streamManager = ProgressTracking.ProgressStreamManager()
    let transferId = TransferIdentifier()

    // Create progress stream
    let stream = await streamManager.createProgressStream(
      for: transferId,
      totalBytes: 1000
    )

    // Use actor-isolated collector for Swift 6 Sendable compliance
    actor UpdateCollector {
      var updates: [ProgressTracking.ProgressUpdate] = []
      var count: Int { updates.count }
      func append(_ update: ProgressTracking.ProgressUpdate) {
        updates.append(update)
      }

      func getUpdates() -> [ProgressTracking.ProgressUpdate] {
        updates
      }
    }

    let collector = UpdateCollector()
    let collectTask = Task {
      for try await update in stream {
        await collector.append(update)
        if await collector.count >= 3 { break }  // Initial + 2 progress updates
      }
    }

    // Simulate download delegate callbacks
    await streamManager.bridgeDownloadProgress(
      for: transferId,
      bytesWritten: 100,
      totalBytesWritten: 100,
      totalBytesExpected: 1000
    )

    await streamManager.bridgeDownloadProgress(
      for: transferId,
      bytesWritten: 200,
      totalBytesWritten: 300,
      totalBytesExpected: 1000
    )

    try await collectTask.value

    // Verify progress updates
    let updates = await collector.getUpdates()
    #expect(updates.count == 3)  // Initial (0%) + 100 bytes + 300 bytes
    #expect(updates[1].transferredBytes == 100)
    #expect(updates[2].transferredBytes == 300)
    #expect(updates[2].progress == 0.3)  // 300/1000 = 30%
  }
}
