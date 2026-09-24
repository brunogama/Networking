// swiftlint:disable file_length
import Foundation
import XCTest

@testable import NetworkingRuntime
import NetworkingDSL
import NetworkingRuntimeDSL
import NetworkingTesting

// Comprehensive tests for FileTransferOperations file upload/download functionality.
// swiftlint:disable:next type_body_length
final class FileTransferOperationsTests: XCTestCase {
  // MARK: - Test Infrastructure

  private var mockClient: FileTransferTestMockClient!

  override func setUp() {
    super.setUp()
    mockClient = FileTransferTestMockClient()
  }

  override func tearDown() {
    mockClient = nil
    super.tearDown()
  }

  // MARK: - FileTransferResult Tests

  func testFileTransferResultSuccessInitialization() {
    let transferId = TransferIdentifier()

    let result = FileTransferResult(
      transferId: transferId,
      bytesTransferred: 1024,
      duration: 1.5,
      averageSpeed: 682.67,
      isSuccessful: true
    )

    XCTAssertEqual(result.transferId, transferId)
    XCTAssertEqual(result.bytesTransferred.rawValue, 1024)
    XCTAssertEqual(result.duration.rawValue, 1.5)
    XCTAssertEqual(result.averageSpeed.rawValue, 682.67, accuracy: 0.01)
    XCTAssertTrue(result.isSuccessful.rawValue)
    XCTAssertNil(result.error)
    XCTAssertNil(result.resumeData)
    XCTAssertNil(result.fileURL)
  }

  func testFileTransferResultFailureWithResumeData() {
    let transferId = TransferIdentifier()
    let resumeData = TransferResumeData(Data("resume".utf8))
    let error = FileTransferError.transferCancelled

    let result = FileTransferResult(
      transferId: transferId,
      bytesTransferred: 512,
      duration: 0.5,
      averageSpeed: 1024.0,
      isSuccessful: false,
      error: error,
      resumeData: resumeData
    )

    XCTAssertFalse(result.isSuccessful.rawValue)
    XCTAssertNotNil(result.error)
    XCTAssertEqual(result.resumeData, resumeData)
  }

  func testFileTransferResultWithMetadata() {
    let metadata = FileMetadata(
      name: "test.pdf",
      size: 2048,
      mimeType: "application/pdf"
    )

    let result = FileTransferResult(
      transferId: TransferIdentifier(),
      bytesTransferred: 2048,
      duration: 1.0,
      averageSpeed: 2048.0,
      isSuccessful: true,
      fileMetadata: metadata
    )

    XCTAssertNotNil(result.fileMetadata)
    XCTAssertEqual(result.fileMetadata?.name, "test.pdf")
    XCTAssertEqual(result.fileMetadata?.size, 2048)
  }

  // MARK: - FileMetadata Tests

  func testFileMetadataInitialization() {
    let now = Date()

    let metadata = FileMetadata(
      name: "document.pdf",
      size: 4096,
      mimeType: "application/pdf",
      createdAt: now,
      modifiedAt: now,
      checksum: "abc123"
    )

    XCTAssertEqual(metadata.name, "document.pdf")
    XCTAssertEqual(metadata.size.rawValue, 4096)
    XCTAssertEqual(metadata.mimeType, "application/pdf")
    XCTAssertEqual(metadata.createdAt, now)
    XCTAssertEqual(metadata.modifiedAt, now)
    XCTAssertEqual(metadata.checksum, "abc123")
  }

  func testFileMetadataFileExtension() {
    let pdfMetadata = FileMetadata(name: "test.pdf", size: 100)
    XCTAssertEqual(pdfMetadata.fileExtension, "pdf")

    let jpgMetadata = FileMetadata(name: "image.jpg", size: 200)
    XCTAssertEqual(jpgMetadata.fileExtension, "jpg")

    let multiExtMetadata = FileMetadata(name: "archive.tar.gz", size: 300)
    XCTAssertEqual(multiExtMetadata.fileExtension, "gz")
  }

  func testFileMetadataNoExtension() {
    let metadata = FileMetadata(name: "README", size: 100)
    XCTAssertNil(metadata.fileExtension)
  }

  func testFileMetadataHashable() {
    let metadata1 = FileMetadata(name: "test.pdf", size: 100)
    let metadata2 = FileMetadata(name: "test.pdf", size: 100)
    let metadata3 = FileMetadata(name: "other.pdf", size: 100)

    XCTAssertEqual(metadata1, metadata2)
    XCTAssertNotEqual(metadata1, metadata3)

    var set: Set<FileMetadata> = []
    set.insert(metadata1)
    set.insert(metadata2)
    XCTAssertEqual(set.count, 1)
  }

  func testFileMetadataMinimalInitialization() {
    let metadata = FileMetadata(name: "file.txt", size: 0)

    XCTAssertEqual(metadata.name, "file.txt")
    XCTAssertEqual(metadata.size.rawValue, 0)
    XCTAssertNil(metadata.mimeType)
    XCTAssertNil(metadata.createdAt)
    XCTAssertNil(metadata.modifiedAt)
    XCTAssertNil(metadata.checksum)
  }

  // MARK: - FileTransferConfiguration Tests

  func testDefaultFileTransferConfiguration() {
    let config = FileTransferConfiguration.default

    XCTAssertEqual(config.maxFileSize.rawValue, 500 * 1024 * 1024)  // 500MB
    XCTAssertNil(config.supportedMimeTypes)
    XCTAssertTrue(config.enableIntegrityCheck.rawValue)
    XCTAssertTrue(config.allowResumableTransfers.rawValue)
    XCTAssertNil(config.temporaryDirectory)
  }

  func testCustomFileTransferConfiguration() {
    let tempDir = TemporaryDirectoryURL(URL(fileURLWithPath: "/tmp/transfers"))

    let config = FileTransferConfiguration(
      maxFileSize: FileSize(100 * 1024 * 1024),
      supportedMimeTypes: ["image/jpeg", "image/png"],
      enableIntegrityCheck: false,
      checksumAlgorithm: .sha512,
      allowResumableTransfers: false,
      temporaryDirectory: tempDir
    )

    XCTAssertEqual(config.maxFileSize.rawValue, 100 * 1024 * 1024)
    XCTAssertEqual(config.supportedMimeTypes?.count, 2)
    XCTAssertFalse(config.enableIntegrityCheck.rawValue)
    XCTAssertFalse(config.allowResumableTransfers.rawValue)
    XCTAssertEqual(config.temporaryDirectory, tempDir)
  }

  func testFileTransferConfigurationChecksumAlgorithm() {
    let sha256Config = FileTransferConfiguration(checksumAlgorithm: .sha256)
    let sha512Config = FileTransferConfiguration(checksumAlgorithm: .sha512)

    if case .sha256 = sha256Config.checksumAlgorithm {
      // Success
    } else {
      XCTFail("Expected SHA-256 algorithm")
    }

    if case .sha512 = sha512Config.checksumAlgorithm {
      // Success
    } else {
      XCTFail("Expected SHA-512 algorithm")
    }
  }

  // MARK: - ChecksumAlgorithm Tests

  func testChecksumAlgorithmCases() {
    let algorithms = ChecksumAlgorithm.allCases

    XCTAssertEqual(algorithms.count, 2)
    XCTAssertTrue(algorithms.contains(.sha256))
    XCTAssertTrue(algorithms.contains(.sha512))
  }

  func testChecksumAlgorithmRawValues() {
    XCTAssertEqual(ChecksumAlgorithm.sha256.identifier.rawValue, "sha256")
    XCTAssertEqual(ChecksumAlgorithm.sha512.identifier.rawValue, "sha512")
  }

  func testChecksumAlgorithmHashFunction() {
    let testData = Data("test data".utf8)

    let sha256Hash = ChecksumAlgorithm.sha256.hash(HTTPBody(testData))
    let sha512Hash = ChecksumAlgorithm.sha512.hash(HTTPBody(testData))

    XCTAssertEqual(sha256Hash.count, 32)  // SHA-256 produces 32 bytes
    XCTAssertEqual(sha512Hash.count, 64)  // SHA-512 produces 64 bytes
  }

  // MARK: - BackgroundTransferConfiguration Tests

  func testDefaultBackgroundTransferConfiguration() {
    let config = BackgroundTransferConfiguration.default

    XCTAssertFalse(config.enableBackgroundTransfer.rawValue)
    XCTAssertEqual(config.backgroundSessionIdentifier, "Networking.BackgroundTransfer")
    XCTAssertTrue(config.allowsCellularAccess.rawValue)
    XCTAssertFalse(config.allowsExpensiveNetworkAccess.rawValue)
    XCTAssertEqual(config.timeoutIntervalForRequest.rawValue, 60.0)
    XCTAssertEqual(config.timeoutIntervalForResource.rawValue, 3600.0)
  }

  func testCustomBackgroundTransferConfiguration() {
    let config = BackgroundTransferConfiguration(
      enableBackgroundTransfer: true,
      backgroundSessionIdentifier: "com.app.backgroundTransfer",
      allowsCellularAccess: false,
      allowsExpensiveNetworkAccess: true,
      timeoutIntervalForRequest: 120.0,
      timeoutIntervalForResource: 7200.0
    )

    XCTAssertTrue(config.enableBackgroundTransfer.rawValue)
    XCTAssertEqual(config.backgroundSessionIdentifier, "com.app.backgroundTransfer")
    XCTAssertFalse(config.allowsCellularAccess.rawValue)
    XCTAssertTrue(config.allowsExpensiveNetworkAccess.rawValue)
    XCTAssertEqual(config.timeoutIntervalForRequest.rawValue, 120.0)
    XCTAssertEqual(config.timeoutIntervalForResource.rawValue, 7200.0)
  }

  // MARK: - FileTransferError Tests

  func testFileTransferErrorFileTooLarge() {
    let error = FileTransferError.fileTooLarge(size: 1024, maxSize: 512)

    XCTAssertNotNil(error.errorDescription)
    XCTAssertTrue(error.errorDescription?.contains("1024") ?? false)
    XCTAssertTrue(error.errorDescription?.contains("512") ?? false)
  }

  func testFileTransferErrorUnsupportedFileType() {
    let error = FileTransferError.unsupportedFileType(mimeType: "video/mp4")

    XCTAssertNotNil(error.errorDescription)
    XCTAssertTrue(error.errorDescription?.contains("video/mp4") ?? false)
  }

  func testFileTransferErrorFileNotFound() {
    let error = FileTransferError.fileNotFound(path: "/path/to/file.txt")

    XCTAssertNotNil(error.errorDescription)
    XCTAssertTrue(error.errorDescription?.contains("/path/to/file.txt") ?? false)
  }

  func testFileTransferErrorInsufficientStorage() {
    let error = FileTransferError.insufficientStorage

    XCTAssertNotNil(error.errorDescription)
    XCTAssertTrue(error.errorDescription?.contains("storage") ?? false)
  }

  func testFileTransferErrorChecksumMismatch() {
    let error = FileTransferError.checksumMismatch(expected: "abc123", actual: "xyz789")

    XCTAssertNotNil(error.errorDescription)
    XCTAssertTrue(error.errorDescription?.contains("abc123") ?? false)
    XCTAssertTrue(error.errorDescription?.contains("xyz789") ?? false)
  }

  func testFileTransferErrorTransferCancelled() {
    let error = FileTransferError.transferCancelled

    XCTAssertNotNil(error.errorDescription)
    XCTAssertTrue(error.errorDescription?.contains("cancelled") ?? false)
  }

  func testFileTransferErrorResumeDataCorrupted() {
    let error = FileTransferError.resumeDataCorrupted

    XCTAssertNotNil(error.errorDescription)
    XCTAssertTrue(error.errorDescription?.contains("Resume data") ?? false)
  }

  func testFileTransferErrorBackgroundTransferNotSupported() {
    let error = FileTransferError.backgroundTransferNotSupported

    XCTAssertNotNil(error.errorDescription)
    XCTAssertTrue(error.errorDescription?.contains("Background") ?? false)
  }

  func testFileTransferErrorTemporaryDirectoryUnavailable() {
    let error = FileTransferError.temporaryDirectoryUnavailable

    XCTAssertNotNil(error.errorDescription)
    XCTAssertTrue(error.errorDescription?.contains("Temporary directory") ?? false)
  }

  func testFileTransferErrorConformsToLocalizedError() {
    let errors: [FileTransferError] = [
      .fileTooLarge(size: 100, maxSize: 50),
      .unsupportedFileType(mimeType: "test"),
      .fileNotFound(path: "/test"),
      .insufficientStorage,
      .checksumMismatch(expected: "a", actual: "b"),
      .transferCancelled,
      .resumeDataCorrupted,
      .backgroundTransferNotSupported,
      .temporaryDirectoryUnavailable,
    ]

    for error in errors {
      XCTAssertNotNil(error.errorDescription)
    }
  }

  // MARK: - FileTransferOperations Tests

  func testFileTransferOperationsInitialization() async {
    let operations = FileTransferOperations(
      httpClient: mockClient,
      configuration: .default
    )

    XCTAssertNotNil(operations)
  }

  func testFileTransferOperationsWithCustomConfiguration() async {
    let config = FileTransferConfiguration(
      maxFileSize: FileSize(10 * 1024 * 1024),
      enableIntegrityCheck: true
    )

    let operations = FileTransferOperations(
      httpClient: mockClient,
      configuration: config
    )

    XCTAssertNotNil(operations)
  }

  func testFileTransferOperationsWithBackgroundEnabled() async {
    let bgConfig = BackgroundTransferConfiguration(
      enableBackgroundTransfer: true
    )

    let config = FileTransferConfiguration(
      backgroundTransferConfiguration: bgConfig
    )

    let operations = FileTransferOperations(
      httpClient: mockClient,
      configuration: config
    )

    XCTAssertNotNil(operations)
  }

  func testDownloadFileReturnsCallerDestinationURL() async throws {
    let payload = Data("downloaded file".utf8)
    mockClient.responseData = payload
    let operations = FileTransferOperations(httpClient: mockClient)
    let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString
    )
    defer { try? FileManager.default.removeItem(at: destinationURL) }

    let result = try await operations.downloadFile(
      from: RemoteTransferURL(try XCTUnwrap(URL(string: "https://example.com/file.bin"))),
      to: LocalFileURL(destinationURL)
    )

    XCTAssertEqual(result.fileURL, LocalFileURL(destinationURL))
    XCTAssertEqual(try Data(contentsOf: destinationURL), payload)
  }

  func testDownloadDataExecutesExactlyOneRequest() async throws {
    let payload = Data("single response".utf8)
    mockClient.responseData = payload
    let operations = FileTransferOperations(httpClient: mockClient)

    let download = try await operations.downloadData(
      from: RemoteTransferURL(try XCTUnwrap(URL(string: "https://example.com/file.bin")))
    )

    XCTAssertEqual(download.data.rawValue, payload)
    XCTAssertEqual(mockClient.executeCallCount, 1)
  }

  func testProgressMiddlewareReportsCompletedDownloadWithoutArtificialDelay() async throws {
    let callback = ProgressCallbackRecorder()
    let request = HTTPRequest(
      method: .get,
      url: HTTPRequestURL(try XCTUnwrap(URL(string: "https://example.com/file.bin")))
    )
    let payload = Data(repeating: 0x5A, count: 4 * 1024 * 1024)
    let response = HTTPResponse(
      request: request,
      status: .ok,
      headers: ["Content-Length": "\(payload.count)"],
      body: HTTPBody(payload)
    )
    let middleware = ProgressTrackingMiddleware(
      configuration: ProgressTrackingConfiguration(
        minimumBytesThreshold: 1,
        updateIntervalBytes: 1,
        maxUpdateInterval: 0
      )
    )
    await middleware.setProgressCallback(for: request.id) { progress in
      Task { await callback.record(progress) }
    }
    _ = try await middleware.modifyRequest(request)

    let clock = ContinuousClock()
    let start = clock.now
    _ = try await middleware.processResponse(response, for: request)
    let elapsed = start.duration(to: clock.now)

    let terminalProgress = await callback.waitForTerminalProgress()
    XCTAssertEqual(terminalProgress?.phase, .completed)
    XCTAssertEqual(terminalProgress?.transferredBytes, TransferByteCount(Int64(payload.count)))
    XCTAssertLessThan(elapsed, .milliseconds(200))
  }

  func testDownloadDataUsesNativeFileTransportOnce() async throws {
    let payload = Data("native download".utf8)
    let client = FileTransferTestNativeClient(downloadedData: payload)
    let operations = FileTransferOperations(httpClient: client)

    let download = try await operations.downloadData(
      from: RemoteTransferURL(try XCTUnwrap(URL(string: "https://example.com/native.bin")))
    )
    let calls = await client.calls

    XCTAssertEqual(download.data.rawValue, payload)
    XCTAssertEqual(calls.download, 1)
    XCTAssertEqual(calls.execute, 0)
  }

  func testUploadFileUsesNativeFileTransportWithoutRequestBody() async throws {
    let sourceURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let payload = Data("native upload".utf8)
    try payload.write(to: sourceURL)
    defer { try? FileManager.default.removeItem(at: sourceURL) }
    let client = FileTransferTestNativeClient(downloadedData: Data())
    let operations = FileTransferOperations(
      httpClient: client,
      configuration: FileTransferConfiguration(enableIntegrityCheck: false)
    )

    let result = try await operations.uploadFile(
      from: LocalFileURL(sourceURL),
      to: RemoteTransferURL(try XCTUnwrap(URL(string: "https://example.com/upload.bin")))
    )
    let calls = await client.calls

    XCTAssertEqual(result.bytesTransferred, TransferByteCount(Int64(payload.count)))
    XCTAssertEqual(calls.upload, 1)
    XCTAssertEqual(calls.execute, 0)
    XCTAssertEqual(calls.uploadedFileURL, sourceURL)
    XCTAssertFalse(calls.uploadRequestHasBody)
  }

  func testFileTransportFallsBackToExecuteWhenNativeTransferIsUnavailable() async throws {
    let payload = Data("retry compatible download".utf8)
    let client = FileTransferTestNativeClient(
      downloadedData: payload,
      canPerformNativeFileTransfer: false
    )
    let operations = FileTransferOperations(httpClient: client)

    let download = try await operations.downloadData(
      from: RemoteTransferURL(try XCTUnwrap(URL(string: "https://example.com/fallback.bin")))
    )
    let calls = await client.calls

    XCTAssertEqual(download.data.rawValue, payload)
    XCTAssertEqual(calls.execute, 1)
    XCTAssertEqual(calls.download, 0)
  }

  func testResumeTransferReturnsWhenBackgroundTaskFinishesWithError() async {
    #if !os(Linux)
    let backgroundConfiguration = BackgroundTransferConfiguration(
      enableBackgroundTransfer: true,
      backgroundSessionIdentifier: BackgroundSessionIdentifier(
        "NetworkingTests.\(UUID().uuidString)"
      )
    )
    let operations = FileTransferOperations(
      httpClient: mockClient,
      configuration: FileTransferConfiguration(
        backgroundTransferConfiguration: backgroundConfiguration
      )
    )

    let returnedBeforeTimeout = await withTaskGroup(of: Bool.self) { group in
      group.addTask {
        do {
          _ = try await operations.resumeTransfer(
            with: TransferResumeData(Data("invalid resume data".utf8))
          )
        } catch {
          return true
        }
        return true
      }
      group.addTask {
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        return false
      }

      let result = await group.next() ?? false
      group.cancelAll()
      return result
    }

    XCTAssertTrue(returnedBeforeTimeout, "resumeTransfer waited after the task completed")
    #endif
  }

  // swiftlint:disable:next function_body_length
  func testBackgroundDelegatePreservesDownloadAndForwardsTaskIdentity() async throws {
    #if !os(Linux)
    let downloadDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString,
      isDirectory: true
    )
    defer { try? FileManager.default.removeItem(at: downloadDirectory) }

    let recorder = BackgroundTransferEventRecorder()
    let progressRecorded = expectation(description: "Progress recorded")
    let completionRecorded = expectation(description: "Completion recorded")
    let delegate = BackgroundTransferDelegate(
      downloadDirectory: downloadDirectory,
      progressHandler: { task, totalBytesWritten, totalBytesExpected in
        await recorder.recordProgress(
          task: task,
          totalBytesWritten: totalBytesWritten,
          totalBytesExpected: totalBytesExpected
        )
        progressRecorded.fulfill()
      },
      completionHandler: { task, completion in
        await recorder.recordCompletion(
          task: task,
          completion: completion
        )
        completionRecorded.fulfill()
      }
    )
    let session = URLSession(configuration: .ephemeral)
    defer { session.invalidateAndCancel() }
    let requestURL = try XCTUnwrap(URL(string: "https://example.com/archive.bin"))
    let task = session.downloadTask(with: requestURL)
    let payload = Data("resumed download".utf8)
    let temporaryDownload = downloadDirectory.appendingPathComponent("url-session.tmp")
    try FileManager.default.createDirectory(
      at: downloadDirectory,
      withIntermediateDirectories: true
    )
    try payload.write(to: temporaryDownload)

    delegate.urlSession(
      session,
      downloadTask: task,
      didWriteData: Int64(payload.count),
      totalBytesWritten: Int64(payload.count),
      totalBytesExpectedToWrite: Int64(payload.count)
    )
    delegate.urlSession(
      session,
      downloadTask: task,
      didFinishDownloadingTo: temporaryDownload
    )
    delegate.urlSession(session, task: task, didCompleteWithError: nil)

    await fulfillment(of: [progressRecorded, completionRecorded], timeout: 1)

    let events = await recorder.events
    XCTAssertTrue(events.progress?.task === task)
    XCTAssertEqual(events.progress?.totalBytesWritten, Int64(payload.count))
    XCTAssertEqual(events.progress?.totalBytesExpected, Int64(payload.count))
    XCTAssertTrue(events.completion?.task === task)
    XCTAssertEqual(events.order, ["progress", "completion"])

    guard case .success(let storedFile) = events.completion?.completion else {
      return XCTFail("Expected a persisted download")
    }
    XCTAssertEqual(try Data(contentsOf: storedFile), payload)
    XCTAssertEqual(storedFile.deletingLastPathComponent(), downloadDirectory)
    #endif
  }

  func testBackgroundCoordinatorReturnsClaimedDownloadURL() async throws {
    #if !os(Linux)
    let downloadDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString,
      isDirectory: true
    )
    defer { try? FileManager.default.removeItem(at: downloadDirectory) }
    try FileManager.default.createDirectory(
      at: downloadDirectory,
      withIntermediateDirectories: true
    )
    let downloadedFile = downloadDirectory.appendingPathComponent("claimed.bin")
    let payload = Data("claimed download".utf8)
    try payload.write(to: downloadedFile)

    let coordinator = BackgroundTransferCoordinator(configuration: .default)
    let session = URLSession(configuration: .ephemeral)
    defer { session.invalidateAndCancel() }
    let task = session.downloadTask(
      with: try XCTUnwrap(URL(string: "https://example.invalid/claimed.bin"))
    )
    let transferId = TransferIdentifier()

    let completion = Task {
      try await Task.sleep(nanoseconds: 10_000_000)
      await coordinator.didComplete(task: task, completion: .success(downloadedFile))
    }
    let result = try await coordinator.resume(
      task: task,
      transferId: transferId,
      progressCallback: nil
    )
    _ = await completion.result

    XCTAssertEqual(result.transferId, transferId)
    XCTAssertEqual(result.fileURL, LocalFileURL(downloadedFile))
    XCTAssertEqual(result.bytesTransferred, TransferByteCount(Int64(payload.count)))
    XCTAssertEqual(try Data(contentsOf: downloadedFile), payload)
    #endif
  }

  func testBackgroundDelegateRemovesDownloadWhenTerminalOwnerNoLongerClaimsTask() async throws {
    #if !os(Linux)
    let downloadDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString,
      isDirectory: true
    )
    defer { try? FileManager.default.removeItem(at: downloadDirectory) }

    let coordinator = BackgroundTransferCoordinator(configuration: .default)
    let completionHandled = expectation(description: "Completion handled")
    let delegate = BackgroundTransferDelegate(
      downloadDirectory: downloadDirectory,
      progressHandler: { _, _, _ in },
      completionHandler: { task, completion in
        await coordinator.didComplete(task: task, completion: completion)
        completionHandled.fulfill()
      }
    )
    let session = URLSession(configuration: .ephemeral)
    defer { session.invalidateAndCancel() }
    let requestURL = try XCTUnwrap(URL(string: "https://example.com/unclaimed.bin"))
    let task = session.downloadTask(with: requestURL)
    let temporaryDownload = downloadDirectory.appendingPathComponent("url-session.tmp")
    try FileManager.default.createDirectory(
      at: downloadDirectory,
      withIntermediateDirectories: true
    )
    try Data("unclaimed download".utf8).write(to: temporaryDownload)

    delegate.urlSession(
      session,
      downloadTask: task,
      didFinishDownloadingTo: temporaryDownload
    )
    delegate.urlSession(session, task: task, didCompleteWithError: nil)

    await fulfillment(of: [completionHandled], timeout: 1)

    let remainingFiles = try FileManager.default.contentsOfDirectory(
      at: downloadDirectory,
      includingPropertiesForKeys: nil
    )
    XCTAssertTrue(remainingFiles.isEmpty, "Unclaimed downloads must not remain on disk")
    #endif
  }

  // MARK: - Sendable Conformance Tests

  func testFileTransferResultSendable() {
    let result: Sendable = FileTransferResult(
      transferId: TransferIdentifier(),
      bytesTransferred: 100,
      duration: 1.0,
      averageSpeed: 100.0,
      isSuccessful: true
    )

    XCTAssertNotNil(result)
  }

  func testFileMetadataSendable() {
    let metadata: Sendable = FileMetadata(name: "test.txt", size: 100)
    XCTAssertNotNil(metadata)
  }

  func testFileTransferConfigurationSendable() {
    let config: Sendable = FileTransferConfiguration.default
    XCTAssertNotNil(config)
  }

  func testBackgroundTransferConfigurationSendable() {
    let config: Sendable = BackgroundTransferConfiguration.default
    XCTAssertNotNil(config)
  }

  func testChecksumAlgorithmSendable() {
    let algorithm: Sendable = ChecksumAlgorithm.sha256
    XCTAssertNotNil(algorithm)
  }

  // MARK: - Edge Case Tests

  func testZeroSizeFile() {
    let metadata = FileMetadata(name: "empty.txt", size: 0)
    XCTAssertEqual(metadata.size.rawValue, 0)
  }

  func testMaxFileSize() {
    let maxSize = Int64.max

    let result = FileTransferResult(
      transferId: TransferIdentifier(),
      bytesTransferred: TransferByteCount(maxSize),
      duration: 1.0,
      averageSpeed: TransferSpeed(Double(maxSize)),
      isSuccessful: true
    )

    XCTAssertEqual(result.bytesTransferred.rawValue, maxSize)
  }

  func testFileMetadataWithSpecialCharactersInName() {
    let metadata = FileMetadata(
      name: "file with spaces & special (chars).pdf",
      size: 100
    )

    XCTAssertEqual(metadata.fileExtension, "pdf")
    XCTAssertTrue(metadata.name.contains(" "))
  }

  func testFileMetadataWithNoNameExtension() {
    let metadata = FileMetadata(name: ".gitignore", size: 50)
    XCTAssertEqual(metadata.fileExtension, "gitignore")
  }

  func testConfigurationWithAllMimeTypes() {
    let mimeTypes: Set<HTTPMediaType> = [
      "application/pdf",
      "image/jpeg",
      "image/png",
      "video/mp4",
      "audio/mpeg",
      "text/plain",
      "application/json",
    ]

    let config = FileTransferConfiguration(supportedMimeTypes: mimeTypes)

    XCTAssertEqual(config.supportedMimeTypes?.count, 7)
  }

  func testVeryLongFilename() {
    let longName = String(repeating: "a", count: 1000) + ".txt"
    let metadata = FileMetadata(name: FileName(longName), size: 100)

    XCTAssertEqual(metadata.fileExtension, "txt")
    XCTAssertEqual(metadata.name.rawValue.count, 1004)
  }

  func testFileTransferResultZeroDuration() {
    let result = FileTransferResult(
      transferId: TransferIdentifier(),
      bytesTransferred: 1000,
      duration: 0,
      averageSpeed: 0,
      isSuccessful: true
    )

    XCTAssertEqual(result.duration.rawValue, 0)
    XCTAssertEqual(result.averageSpeed.rawValue, 0)
  }

  func testFileTransferResultNegativeDuration() {
    // Edge case - should not happen but test handling
    let result = FileTransferResult(
      transferId: TransferIdentifier(),
      bytesTransferred: 100,
      duration: -1.0,
      averageSpeed: -100.0,
      isSuccessful: false
    )

    XCTAssertLessThan(result.duration.rawValue, 0)
  }
}

#if !os(Linux)
private actor BackgroundTransferEventRecorder {
  struct Events {
    let progress: ProgressEvent?
    let completion: CompletionEvent?
    let order: [String]
  }

  struct ProgressEvent {
    let task: URLSessionDownloadTask
    let totalBytesWritten: Int64
    let totalBytesExpected: Int64
  }

  struct CompletionEvent {
    let task: URLSessionTask
    let completion: BackgroundTransferCompletion
  }

  private(set) var progress: ProgressEvent?
  private(set) var completion: CompletionEvent?
  private var order: [String] = []

  var events: Events {
    Events(progress: progress, completion: completion, order: order)
  }

  func recordProgress(
    task: URLSessionDownloadTask,
    totalBytesWritten: Int64,
    totalBytesExpected: Int64
  ) {
    progress = ProgressEvent(
      task: task,
      totalBytesWritten: totalBytesWritten,
      totalBytesExpected: totalBytesExpected
    )
    order.append("progress")
  }

  func recordCompletion(
    task: URLSessionTask,
    completion: BackgroundTransferCompletion
  ) {
    self.completion = CompletionEvent(
      task: task,
      completion: completion
    )
    order.append("completion")
  }
}
#endif

// MARK: - Test Mock HTTP Client

private final class FileTransferTestMockClient: HTTPClient, @unchecked Sendable {
  private let lock = NSLock()
  private var storedExecuteCallCount = 0
  var shouldFail = false
  var failureError: HTTPError?
  var responseData: Data?

  var executeCallCount: Int {
    lock.withLock { storedExecuteCallCount }
  }

  func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
    lock.withLock {
      storedExecuteCallCount += 1
    }

    if shouldFail {
      throw failureError ?? HTTPError(category: .network(.serverUnreachable), request: request)
    }

    return HTTPResponse(
      request: request,
      status: .ok,
      headers: [:],
      body: responseData ?? Data()
    )
  }

}

private actor FileTransferTestNativeClient: HTTPFileTransferClient {
  struct Calls: Sendable {
    var execute = 0
    var upload = 0
    var download = 0
    var uploadedFileURL: URL?
    var uploadRequestHasBody = false
  }

  private let downloadedData: Data
  private var storedCalls = Calls()
  nonisolated let canPerformNativeFileTransfer: Bool

  init(downloadedData: Data, canPerformNativeFileTransfer: Bool = true) {
    self.downloadedData = downloadedData
    self.canPerformNativeFileTransfer = canPerformNativeFileTransfer
  }

  var calls: Calls {
    storedCalls
  }

  func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
    storedCalls.execute += 1
    return HTTPResponse(request: request, status: .ok, body: HTTPBody(downloadedData))
  }

  func upload(
    _ request: HTTPRequest,
    fromFile fileURL: URL,
    progress: (@Sendable (HTTPFileTransferProgress) -> Void)?
  ) async throws -> HTTPResponse {
    storedCalls.upload += 1
    storedCalls.uploadedFileURL = fileURL
    storedCalls.uploadRequestHasBody = request.body != nil
    let fileSize = try Data(contentsOf: fileURL).count
    progress?(
      HTTPFileTransferProgress(transferredBytes: Int64(fileSize), totalBytes: Int64(fileSize))
    )
    return HTTPResponse(request: request, status: .ok, headers: HTTPHeaders())
  }

  func download(
    _ request: HTTPRequest,
    progress: (@Sendable (HTTPFileTransferProgress) -> Void)?
  ) async throws -> HTTPFileDownload {
    storedCalls.download += 1
    let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString
    )
    try downloadedData.write(to: temporaryURL)
    progress?(
      HTTPFileTransferProgress(
        transferredBytes: Int64(downloadedData.count),
        totalBytes: Int64(downloadedData.count)
      )
    )
    return HTTPFileDownload(
      temporaryFileURL: temporaryURL,
      response: HTTPResponse(request: request, status: .ok, headers: HTTPHeaders())
    )
  }
}

private actor ProgressCallbackRecorder {
  private var updates: [TransferProgress] = []

  func record(_ progress: TransferProgress) {
    updates.append(progress)
  }

  func waitForTerminalProgress() async -> TransferProgress? {
    for _ in 0..<100 {
      if let terminal = updates.last(where: { $0.phase == .completed || $0.phase == .failed }) {
        return terminal
      }
      await Task.yield()
    }
    return updates.last
  }
}
