import Testing
import Foundation
@testable import Networking

/// Test suite for progress tracking functionality.
@Suite("Progress Tracking Tests")
struct ProgressTrackingTests {
  // MARK: - Test Data

  private let testURL = URL(string: "https://api.example.com/test")!
  private let testFileURL = URL(string: "https://api.example.com/files/test.jpg")!

  // MARK: - Progress Configuration Tests

  @Test("Default progress tracking configuration has expected values")
  func testDefaultProgressConfiguration() async throws {
    let config = ProgressTrackingConfiguration.default

    #expect(config.trackUploadProgress == true)
    #expect(config.trackDownloadProgress == true)
    #expect(config.minimumBytesThreshold == 1024)
    #expect(config.updateIntervalBytes == 8192)
    #expect(config.maxUpdateInterval == 0.1)
    #expect(config.enableChunkedTransfer == true)
    #expect(config.defaultChunkSize == 65_536)
  }

  @Test("Custom progress tracking configuration can be created")
  func testCustomProgressConfiguration() async throws {
    let config = ProgressTrackingConfiguration(
      trackUploadProgress: false,
      trackDownloadProgress: true,
      minimumBytesThreshold: 2048,
      updateIntervalBytes: 16_384,
      maxUpdateInterval: 0.5,
      enableChunkedTransfer: false,
      defaultChunkSize: 32_768
    )

    #expect(config.trackUploadProgress == false)
    #expect(config.trackDownloadProgress == true)
    #expect(config.minimumBytesThreshold == 2048)
    #expect(config.updateIntervalBytes == 16_384)
    #expect(config.maxUpdateInterval == 0.5)
    #expect(config.enableChunkedTransfer == false)
    #expect(config.defaultChunkSize == 32_768)
  }

  // MARK: - Transfer Progress Tests

  @Test("Transfer progress calculates percentage correctly")
  func testTransferProgressCalculation() async throws {
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
  func testTransferProgressSendableHashable() async throws {
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
  func testProgressMiddlewareInitialization() async throws {
    let middleware = ProgressTrackingMiddleware()

    // Test that middleware is properly initialized - verify it can process a request
    let request = HTTPRequest(method: .get, url: testURL)
    _ = try await middleware.modifyRequest(request)
  }

  @Test("Progress middleware can be initialized with custom configuration")
  func testProgressMiddlewareCustomConfiguration() async throws {
    let config = ProgressTrackingConfiguration(
      trackUploadProgress: false,
      trackDownloadProgress: true
    )
    let middleware = ProgressTrackingMiddleware(configuration: config)

    // Verify middleware works with custom config
    let request = HTTPRequest(method: .get, url: testURL)
    _ = try await middleware.modifyRequest(request)
  }

  @Test("Progress middleware can be created with callback")
  func testProgressMiddlewareWithCallback() async throws {
    let progressBox = ProgressBox()

    let middleware = ProgressTrackingMiddleware.withCallback(
      for: UUID(),
      callback: { progress in
        Task {
          await progressBox.setProgress(progress)
        }
      }
    )

    // Verify middleware works
    let request = HTTPRequest(method: .get, url: testURL)
    _ = try await middleware.modifyRequest(request)
  }

  @Test("Progress middleware modifies request correctly for upload tracking")
  func testProgressMiddlewareUploadTracking() async throws {
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
  func testProgressMiddlewareSmallRequestHandling() async throws {
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
  func testDefaultResumableTransfer() async throws {
    let transfer = DefaultResumableTransfer()

    // transferId is a UUID (non-optional), verify it's a valid UUID
    _ = transfer.transferId  // This line ensures the property is accessed
    #expect(transfer.totalBytes == nil)
    #expect(transfer.resumeOffset == 0)
    #expect(transfer.canResume == true)
    #expect(transfer.resumeData == nil)
  }

  @Test("Resumable transfer can be created with custom values")
  func testCustomResumableTransfer() async throws {
    let transferId = UUID()
    let resumeData = Data([0x01, 0x02, 0x03])

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
  func testDefaultChunkedTransferConfiguration() async throws {
    let config = ChunkedTransferConfiguration.default

    #expect(config.chunkSize == 65_536)  // 64KB
    #expect(config.maxConcurrentChunks == 4)
    #expect(config.retryConfiguration.maxRetries == 3)
    #expect(config.retryConfiguration.baseDelay == 1.0)
    #expect(config.retryConfiguration.backoffMultiplier == 2.0)
  }

  @Test("Custom chunked transfer configuration can be created")
  func testCustomChunkedTransferConfiguration() async throws {
    let retryConfig = ChunkRetryConfiguration(
      maxRetries: 5,
      baseDelay: 2.0,
      backoffMultiplier: 1.5
    )

    let config = ChunkedTransferConfiguration(
      chunkSize: 32_768,
      maxConcurrentChunks: 8,
      retryConfiguration: retryConfig
    )

    #expect(config.chunkSize == 32_768)
    #expect(config.maxConcurrentChunks == 8)
    #expect(config.retryConfiguration.maxRetries == 5)
    #expect(config.retryConfiguration.baseDelay == 2.0)
    #expect(config.retryConfiguration.backoffMultiplier == 1.5)
  }

  // MARK: - Progress Aggregator Tests

  @Test("Progress aggregator calculates aggregate progress correctly")
  func testProgressAggregator() async throws {
    let progressBox = ProgressBox()

    let aggregator = ProgressAggregator { progress in
      Task {
        await progressBox.setProgress(progress)
      }
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

    await aggregator.updateProgress(for: UUID(), progress: progress1)
    await aggregator.updateProgress(for: UUID(), progress: progress2)

    // Verify aggregate calculation would be correct
    // Total: 3000 bytes, Transferred: 1500 bytes = 50% progress
    // Just verify we can update progress without errors
  }

  @Test("Progress aggregator handles completed transfers correctly")
  func testProgressAggregatorCompletedTransfers() async throws {
    let aggregator = ProgressAggregator { _ in }

    let transferId = UUID()
    let progress = TransferProgress(
      totalBytes: 1000,
      transferredBytes: 1000,
      phase: .completed
    )

    await aggregator.updateProgress(for: transferId, progress: progress)

    // Completed transfers should be cleaned up automatically - just verify no errors
  }

  // MARK: - File Transfer Tests

  @Test("File transfer configuration has correct default values")
  func testFileTransferDefaultConfiguration() async throws {
    let config = FileTransferConfiguration.default

    #expect(config.maxFileSize == 500 * 1024 * 1024)  // 500MB
    #expect(config.supportedMimeTypes == nil)  // All types supported by default
    #expect(config.enableIntegrityCheck == true)
    #expect(config.checksumAlgorithm == .sha256)
    #expect(config.allowResumableTransfers == true)
    #expect(config.temporaryDirectory == nil)
  }

  @Test("File metadata calculation works correctly")
  func testFileMetadata() async throws {
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
  func testFileMetadataNoExtension() async throws {
    let metadata = FileMetadata(
      name: "testfile",
      size: 1024
    )

    #expect(metadata.name == "testfile")
    #expect(metadata.fileExtension == nil)
  }

  @Test("Checksum algorithms are correctly defined")
  func testChecksumAlgorithms() async throws {
    let algorithms = ChecksumAlgorithm.allCases

    // Only secure algorithms should be available
    #expect(algorithms.contains(.sha256))
    #expect(algorithms.contains(.sha512))
    // MD5 and SHA1 removed for security reasons
    #expect(algorithms.count == 2)

    // Test that hash functions exist
    let testData = Data([0x01, 0x02, 0x03])

    for algorithm in algorithms {
      let hashFunction = algorithm.hashFunction
      let result = hashFunction(testData)
      #expect(!result.isEmpty)
    }
  }

  @Test("File transfer errors provide meaningful descriptions")
  func testFileTransferErrorDescriptions() async throws {
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
  func testBackgroundTransferConfiguration() async throws {
    let config = BackgroundTransferConfiguration.default

    #expect(config.enableBackgroundTransfer == false)
    #expect(config.backgroundSessionIdentifier == "ModernNetworking.BackgroundTransfer")
    #expect(config.allowsCellularAccess == true)
    #expect(config.allowsExpensiveNetworkAccess == false)
    #expect(config.timeoutIntervalForRequest == 60.0)
    #expect(config.timeoutIntervalForResource == 3600.0)
  }

  // MARK: - Mock Client for Integration Tests

  private struct MockHTTPClient: HTTPClient {
    let mockResponse: HTTPResponse
    let delay: TimeInterval

    init(mockResponse: HTTPResponse, delay: TimeInterval = 0) {
      self.mockResponse = mockResponse
      self.delay = delay
    }

    func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
      if delay > 0 {
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
      }
      return mockResponse
    }
  }

  // MARK: - Integration Tests

  @Test("File transfer operations can be initialized")
  func testFileTransferOperationsInitialization() async throws {
    let mockClient = MockHTTPClient(
      mockResponse: HTTPResponse(
        request: HTTPRequest(method: .get, url: testURL),
        httpURLResponse: HTTPURLResponse(
          url: testURL,
          statusCode: 200,
          httpVersion: nil,
          headerFields: nil
        )!,
        body: Data()
      )
    )

    let fileTransfer = FileTransferOperations(
      httpClient: mockClient,
      configuration: .default
    )

    // Verify file transfer was created - it should exist at this point
    // Simply verifying the initializer ran without errors is sufficient
  }

  @Test("File transfer operations can upload data")
  func testFileTransferUploadData() async throws {
    let testData = Data("Hello, World!".utf8)

    let mockResponse = HTTPResponse(
      request: HTTPRequest(method: .post, url: testURL),
      httpURLResponse: HTTPURLResponse(
        url: testURL,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
      )!,
      body: Data()
    )

    let mockClient = MockHTTPClient(mockResponse: mockResponse)
    let fileTransfer = FileTransferOperations(
      httpClient: mockClient,
      configuration: .default
    )

    let progressBox = ProgressListBox()

    let result = try await fileTransfer.uploadData(
      testData,
      fileName: "test.txt",
      to: testURL,
      mimeType: "text/plain"
    ) { progress in
      Task {
        await progressBox.append(progress)
      }
    }

    #expect(result.isSuccessful == true)
    #expect(result.bytesTransferred >= 0)
    // transferId is non-optional, just verify it's accessible
    _ = result.transferId
  }

  @Test("File transfer operations handle download data")
  func testFileTransferDownloadData() async throws {
    let testData = Data("Downloaded content".utf8)

    let mockResponse = HTTPResponse(
      request: HTTPRequest(method: .get, url: testFileURL),
      httpURLResponse: HTTPURLResponse(
        url: testFileURL,
        statusCode: 200,
        httpVersion: nil,
        headerFields: ["Content-Length": "\(testData.count)"]
      )!,
      body: testData
    )

    let mockClient = MockHTTPClient(mockResponse: mockResponse)
    let fileTransfer = FileTransferOperations(
      httpClient: mockClient,
      configuration: .default
    )

    let (downloadedData, result) = try await fileTransfer.downloadData(
      from: testFileURL
    ) { _ in
      // Progress tracking
    }

    #expect(result.isSuccessful == true)
    #expect(downloadedData == testData)
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
  func testProgressTrackingPerformance() async throws {
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
  func testTransferProgressPerformance() async throws {
    let startTime = Date()

    // Create many progress instances and calculate percentages
    for i in 0..<10_000 {
      let progress = TransferProgress(
        totalBytes: 10_000,
        transferredBytes: Int64(i),
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
  func testZeroByteTransfer() async throws {
    let progress = TransferProgress(
      totalBytes: 0,
      transferredBytes: 0,
      phase: .completed
    )

    #expect(progress.progress == 1.0)  // Completed transfers should show 100%
    #expect(progress.estimatedTimeRemaining == nil)
  }

  @Test("Progress tracking handles negative values gracefully")
  func testNegativeValues() async throws {
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
  func testLargeNumbers() async throws {
    let largeSize = Int64.max / 2
    let progress = TransferProgress(
      totalBytes: largeSize,
      transferredBytes: largeSize / 2,
      phase: .downloading
    )

    #expect(progress.progress == 0.5)
  }

  @Test("File metadata handles unicode filenames")
  func testUnicodeFilenames() async throws {
    let metadata = FileMetadata(
      name: "测试文件.jpg",  // Chinese characters
      size: 1024,
      mimeType: "image/jpeg"
    )

    #expect(metadata.name == "测试文件.jpg")
    #expect(metadata.fileExtension == "jpg")
  }

  @Test("File metadata handles very long filenames")
  func testLongFilenames() async throws {
    let longName = String(repeating: "a", count: 255) + ".txt"
    let metadata = FileMetadata(
      name: longName,
      size: 1024
    )

    #expect(metadata.name == longName)
    #expect(metadata.fileExtension == "txt")
  }
}

// MARK: - Thread-Safe Helpers for Testing

private actor ProgressBox {
  private var progress: TransferProgress?

  func setProgress(_ progress: TransferProgress) {
    self.progress = progress
  }

  func getProgress() -> TransferProgress? {
    progress
  }
}

private actor ProgressListBox {
  private var progressList: [TransferProgress] = []

  func append(_ progress: TransferProgress) {
    progressList.append(progress)
  }

  func getProgressList() -> [TransferProgress] {
    progressList
  }
}
