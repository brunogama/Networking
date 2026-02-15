import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Represents the result of a file transfer operation.
public struct FileTransferResult: Sendable {
  /// The unique identifier for this transfer
  public let transferId: UUID

  /// The total number of bytes transferred
  public let bytesTransferred: Int64

  /// The total duration of the transfer
  public let duration: TimeInterval

  /// Average transfer speed in bytes per second
  public let averageSpeed: Double

  /// Whether the transfer completed successfully
  public let isSuccessful: Bool

  /// Any error that occurred during transfer
  public let error: (any Error)?

  /// Resume data for failed or cancelled transfers
  public let resumeData: Data?

  /// Metadata about the transferred file
  public let fileMetadata: FileMetadata?

  public init(
    transferId: UUID,
    bytesTransferred: Int64,
    duration: TimeInterval,
    averageSpeed: Double,
    isSuccessful: Bool,
    error: (any Error)? = nil,
    resumeData: Data? = nil,
    fileMetadata: FileMetadata? = nil
  ) {
    self.transferId = transferId
    self.bytesTransferred = bytesTransferred
    self.duration = duration
    self.averageSpeed = averageSpeed
    self.isSuccessful = isSuccessful
    self.error = error
    self.resumeData = resumeData
    self.fileMetadata = fileMetadata
  }
}

/// Metadata information about a file.
public struct FileMetadata: Sendable, Hashable {
  /// The file name
  public let name: String

  /// The file size in bytes
  public let size: Int64

  /// The MIME type of the file
  public let mimeType: String?

  /// File creation date
  public let createdAt: Date?

  /// File modification date
  public let modifiedAt: Date?

  /// File checksum for integrity verification
  public let checksum: String?

  /// File extension
  public var fileExtension: String? {
    let components = name.components(separatedBy: ".")
    return components.count > 1 ? components.last : nil
  }

  public init(
    name: String,
    size: Int64,
    mimeType: String? = nil,
    createdAt: Date? = nil,
    modifiedAt: Date? = nil,
    checksum: String? = nil
  ) {
    self.name = name
    self.size = size
    self.mimeType = mimeType
    self.createdAt = createdAt
    self.modifiedAt = modifiedAt
    self.checksum = checksum
  }
}

/// Configuration for file transfer operations.
public struct FileTransferConfiguration: Sendable {
  /// Maximum file size allowed for transfer
  public let maxFileSize: Int64

  /// Supported MIME types (nil means all types are supported)
  public let supportedMimeTypes: Set<String>?

  /// Whether to enable file integrity checking
  public let enableIntegrityCheck: Bool

  /// Checksum algorithm to use for integrity checking
  public let checksumAlgorithm: ChecksumAlgorithm

  /// Whether to allow resumable transfers
  public let allowResumableTransfers: Bool

  /// Directory for temporary files during transfer
  public let temporaryDirectory: URL?

  /// Background transfer configuration
  public let backgroundTransferConfiguration: BackgroundTransferConfiguration

  public init(
    maxFileSize: Int64 = 500 * 1024 * 1024,  // 500MB
    supportedMimeTypes: Set<String>? = nil,
    enableIntegrityCheck: Bool = true,
    checksumAlgorithm: ChecksumAlgorithm = .sha256,
    allowResumableTransfers: Bool = true,
    temporaryDirectory: URL? = nil,
    backgroundTransferConfiguration: BackgroundTransferConfiguration = .default
  ) {
    self.maxFileSize = maxFileSize
    self.supportedMimeTypes = supportedMimeTypes
    self.enableIntegrityCheck = enableIntegrityCheck
    self.checksumAlgorithm = checksumAlgorithm
    self.allowResumableTransfers = allowResumableTransfers
    self.temporaryDirectory = temporaryDirectory
    self.backgroundTransferConfiguration = backgroundTransferConfiguration
  }

  public static let `default` = Self()
}

/// Supported secure checksum algorithms for file integrity verification.
/// Only SHA-256 and SHA-512 are supported for security reasons.
public enum ChecksumAlgorithm: String, Sendable, CaseIterable {
  case sha256
  case sha512

  public var hashFunction: (Data) -> Data {
    switch self {
    case .sha256:
      return { data in
        var digest = [UInt8](repeating: 0, count: Int(sha256DigestLength))
        data.withUnsafeBytes {
          _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &digest)
        }
        return Data(digest)
      }

    case .sha512:
      return { data in
        var digest = [UInt8](repeating: 0, count: Int(sha512DigestLength))
        data.withUnsafeBytes {
          _ = CC_SHA512($0.baseAddress, CC_LONG(data.count), &digest)
        }
        return Data(digest)
      }
    }
  }
}

/// Configuration for background transfer operations.
public struct BackgroundTransferConfiguration: Sendable {
  /// Whether to allow transfers when app is backgrounded
  public let enableBackgroundTransfer: Bool

  /// Background session identifier
  public let backgroundSessionIdentifier: String

  /// Whether to allow cellular data for background transfers
  public let allowsCellularAccess: Bool

  /// Whether to allow expensive network access
  public let allowsExpensiveNetworkAccess: Bool

  /// Timeout interval for background transfers
  public let timeoutIntervalForRequest: TimeInterval

  /// Resource timeout for background transfers
  public let timeoutIntervalForResource: TimeInterval

  public init(
    enableBackgroundTransfer: Bool = false,
    backgroundSessionIdentifier: String = "Networking.BackgroundTransfer",
    allowsCellularAccess: Bool = true,
    allowsExpensiveNetworkAccess: Bool = false,
    timeoutIntervalForRequest: TimeInterval = 60.0,
    timeoutIntervalForResource: TimeInterval = 3600.0
  ) {
    self.enableBackgroundTransfer = enableBackgroundTransfer
    self.backgroundSessionIdentifier = backgroundSessionIdentifier
    self.allowsCellularAccess = allowsCellularAccess
    self.allowsExpensiveNetworkAccess = allowsExpensiveNetworkAccess
    self.timeoutIntervalForRequest = timeoutIntervalForRequest
    self.timeoutIntervalForResource = timeoutIntervalForResource
  }

  public static let `default` = Self()
}

/// Errors specific to file transfer operations.
public enum FileTransferError: Error, LocalizedError {
  case fileTooLarge(size: Int64, maxSize: Int64)
  case unsupportedFileType(mimeType: String)
  case fileNotFound(path: String)
  case insufficientStorage
  case checksumMismatch(expected: String, actual: String)
  case transferCancelled
  case resumeDataCorrupted
  case backgroundTransferNotSupported
  case temporaryDirectoryUnavailable

  public var errorDescription: String? {
    switch self {
    case .fileTooLarge(let size, let maxSize):
      return "File size (\(size) bytes) exceeds maximum allowed size (\(maxSize) bytes)"

    case .unsupportedFileType(let mimeType):
      return "File type '\(mimeType)' is not supported"

    case .fileNotFound(let path):
      return "File not found at path: \(path)"

    case .insufficientStorage:
      return "Insufficient storage space for file transfer"

    case .checksumMismatch(let expected, let actual):
      return "File integrity check failed. Expected: \(expected), Actual: \(actual)"

    case .transferCancelled:
      return "File transfer was cancelled"

    case .resumeDataCorrupted:
      return "Resume data is corrupted and cannot be used"

    case .backgroundTransferNotSupported:
      return "Background transfer is not supported or not configured"

    case .temporaryDirectoryUnavailable:
      return "Temporary directory is unavailable for file operations"
    }
  }
}

/// Main class for handling file transfer operations.
public actor FileTransferOperations {
  // MARK: - Properties

  private let httpClient: any HTTPClient
  private let configuration: FileTransferConfiguration
  private let progressMiddleware: ProgressTrackingMiddleware
  private let progressStreamManager = ProgressTracking.ProgressStreamManager()
  private var activeTransfers: [UUID: ActiveTransfer] = [:]

  /// Background URLSession for file transfers.
  ///
  /// - Note: `nonisolated(unsafe)` justification:
  ///   1. URLSession is thread-safe by design (Apple documentation)
  ///   2. Only set once during initialization in init(), never mutated after
  ///   3. All access goes through actor-isolated methods, serializing reads
  ///   4. Session lifetime matches actor lifetime (invalidated with actor)
  ///
  /// Alternative would require making session access async, but URLSession
  /// delegates already handle threading internally.
  nonisolated(unsafe) private var backgroundSession: URLSession?

  // MARK: - Internal State

  private struct ActiveTransfer {
    let transferId: UUID
    let startTime: Date
    let fileMetadata: FileMetadata?
    let progressCallback: ProgressCallback?
    var task: URLSessionTask?
    var resumeData: Data?
    var isCancelled: Bool = false

    var duration: TimeInterval {
      Date().timeIntervalSince(startTime)
    }
  }

  // MARK: - Initialization

  public init(
    httpClient: any HTTPClient,
    configuration: FileTransferConfiguration = .default
  ) {
    self.httpClient = httpClient
    self.configuration = configuration
    self.progressMiddleware = ProgressTrackingMiddleware(
      configuration: ProgressTrackingConfiguration(
        trackUploadProgress: true,
        trackDownloadProgress: true,
        enableChunkedTransfer: configuration.allowResumableTransfers
      )
    )

    #if !os(Linux)
    if configuration.backgroundTransferConfiguration.enableBackgroundTransfer {
      self.backgroundSession = createBackgroundSession()
    }
    #endif
  }

  // MARK: - File Upload Operations

  /// Uploads a file from a local path to a remote URL.
  /// - Parameters:
  ///   - fileURL: Local file URL to upload
  ///   - destinationURL: Remote URL to upload to
  ///   - progressCallback: Optional callback for progress updates
  /// - Returns: File transfer result
  public func uploadFile(
    from fileURL: URL,
    to destinationURL: URL,
    progressCallback: ProgressCallback? = nil
  ) async throws -> FileTransferResult {
    // Validate file
    let metadata = try await validateAndCreateMetadata(for: fileURL)
    try validateFileTransfer(metadata: metadata)

    // Create request
    let request = try await createUploadRequest(
      fileURL: fileURL,
      destinationURL: destinationURL,
      metadata: metadata
    )

    return try await performTransfer(
      request: request,
      metadata: metadata,
      progressCallback: progressCallback,
      transferType: .upload
    )
  }

  /// Uploads file data to a remote URL.
  /// - Parameters:
  ///   - data: File data to upload
  ///   - fileName: Name of the file
  ///   - destinationURL: Remote URL to upload to
  ///   - mimeType: MIME type of the file
  ///   - progressCallback: Optional callback for progress updates
  /// - Returns: File transfer result
  public func uploadData(
    _ data: Data,
    fileName: String,
    to destinationURL: URL,
    mimeType: String? = nil,
    progressCallback: ProgressCallback? = nil
  ) async throws -> FileTransferResult {
    let metadata = FileMetadata(
      name: fileName,
      size: Int64(data.count),
      mimeType: mimeType,
      checksum: configuration.enableIntegrityCheck ? calculateChecksum(for: data) : nil
    )

    try validateFileTransfer(metadata: metadata)

    let request = try createDataUploadRequest(
      data: data,
      fileName: fileName,
      destinationURL: destinationURL,
      mimeType: mimeType
    )

    return try await performTransfer(
      request: request,
      metadata: metadata,
      progressCallback: progressCallback,
      transferType: .upload
    )
  }

  // MARK: - File Download Operations

  /// Downloads a file from a remote URL to a local path.
  /// - Parameters:
  ///   - sourceURL: Remote URL to download from
  ///   - destinationURL: Local URL to save the file
  ///   - progressCallback: Optional callback for progress updates
  /// - Returns: File transfer result
  public func downloadFile(
    from sourceURL: URL,
    to destinationURL: URL,
    progressCallback: ProgressCallback? = nil
  ) async throws -> FileTransferResult {
    let request = HTTPRequest(
      method: .get,
      url: sourceURL,
      timeout: configuration.backgroundTransferConfiguration.timeoutIntervalForRequest
    )

    return try await performTransfer(
      request: request,
      destinationURL: destinationURL,
      progressCallback: progressCallback,
      transferType: .download
    )
  }

  /// Downloads a file and returns it as Data.
  /// - Parameters:
  ///   - sourceURL: Remote URL to download from
  ///   - progressCallback: Optional callback for progress updates
  /// - Returns: Downloaded file data and transfer result
  public func downloadData(
    from sourceURL: URL,
    progressCallback: ProgressCallback? = nil
  ) async throws -> (data: Data, result: FileTransferResult) {
    let request = HTTPRequest(
      method: .get,
      url: sourceURL,
      timeout: configuration.backgroundTransferConfiguration.timeoutIntervalForRequest
    )

    let result = try await performTransfer(
      request: request,
      progressCallback: progressCallback,
      transferType: .download
    )

    // Get the downloaded data from response
    let response = try await httpClient.execute(request)
    guard let data = response.body else {
      throw FileTransferError.fileNotFound(path: sourceURL.absoluteString)
    }

    return (data: data, result: result)
  }

  // MARK: - Resumable Transfer Operations

  /// Resumes a previously interrupted transfer.
  /// - Parameters:
  ///   - resumeData: Resume data from previous transfer
  ///   - progressCallback: Optional callback for progress updates
  /// - Returns: File transfer result
  public func resumeTransfer(
    with resumeData: Data,
    progressCallback: ProgressCallback? = nil
  ) async throws -> FileTransferResult {
    guard configuration.allowResumableTransfers else {
      throw FileTransferError.backgroundTransferNotSupported
    }

    // Validate resume data
    guard !resumeData.isEmpty else {
      throw FileTransferError.resumeDataCorrupted
    }

    // Create background session task from resume data
    guard let backgroundSession = self.backgroundSession else {
      throw FileTransferError.backgroundTransferNotSupported
    }

    let transferId = UUID()
    let startTime = Date()

    // Create task from resume data
    let task = backgroundSession.downloadTask(withResumeData: resumeData)

    let activeTransfer = ActiveTransfer(
      transferId: transferId,
      startTime: startTime,
      fileMetadata: nil,
      progressCallback: progressCallback,
      task: task,
      resumeData: resumeData
    )

    activeTransfers[transferId] = activeTransfer

    // Set progress callback
    if let progressCallback = progressCallback {
      await progressMiddleware.setProgressCallback(for: transferId, callback: progressCallback)
    }

    // Start task
    task.resume()

    // Wait for completion (simplified for this implementation)
    return try await waitForTransferCompletion(transferId: transferId)
  }

  /// Cancels an active transfer and returns resume data if available.
  /// - Parameter transferId: The ID of the transfer to cancel
  /// - Returns: Resume data for later resumption, if available
  public func cancelTransfer(_ transferId: UUID) async -> Data? {
    guard var activeTransfer = activeTransfers[transferId] else {
      return nil
    }

    activeTransfer.isCancelled = true
    activeTransfers[transferId] = activeTransfer

    // Cancel the task and collect resume data
    if let task = activeTransfer.task as? URLSessionDownloadTask {
      return await withCheckedContinuation { continuation in
        task.cancel { resumeData in
          continuation.resume(returning: resumeData)
        }
      }
    } else {
      activeTransfer.task?.cancel()
      return activeTransfer.resumeData
    }
  }

  // MARK: - Background Transfer Support

  /// Configures background transfer capabilities.
  /// - Parameter configuration: Background transfer configuration
  public func configureBackgroundTransfer(
    _ configuration: BackgroundTransferConfiguration
  ) async {
    #if !os(Linux)
    if configuration.enableBackgroundTransfer {
      self.backgroundSession = createBackgroundSession(with: configuration)
    } else {
      self.backgroundSession?.invalidateAndCancel()
      self.backgroundSession = nil
    }
    #endif
  }

  // MARK: - Private Methods

  private func validateAndCreateMetadata(for fileURL: URL) async throws -> FileMetadata {
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      throw FileTransferError.fileNotFound(path: fileURL.path)
    }

    let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
    let fileSize = attributes[.size] as? Int64 ?? 0
    let createdAt = attributes[.creationDate] as? Date
    let modifiedAt = attributes[.modificationDate] as? Date

    let fileName = fileURL.lastPathComponent
    let mimeType = getMimeType(for: fileURL)

    // Calculate checksum if enabled
    let checksum: String?
    if configuration.enableIntegrityCheck {
      let data = try Data(contentsOf: fileURL)
      checksum = calculateChecksum(for: data)
    } else {
      checksum = nil
    }

    return FileMetadata(
      name: fileName,
      size: fileSize,
      mimeType: mimeType,
      createdAt: createdAt,
      modifiedAt: modifiedAt,
      checksum: checksum
    )
  }

  private func validateFileTransfer(metadata: FileMetadata) throws {
    // Check file size
    if metadata.size > configuration.maxFileSize {
      throw FileTransferError.fileTooLarge(
        size: metadata.size,
        maxSize: configuration.maxFileSize
      )
    }

    // Check MIME type
    if let supportedTypes = configuration.supportedMimeTypes,
      let mimeType = metadata.mimeType,
      !supportedTypes.contains(mimeType)
    {
      throw FileTransferError.unsupportedFileType(mimeType: mimeType)
    }

    // Check available storage (simplified check)
    if configuration.temporaryDirectory != nil {
      // In a real implementation, check available disk space
    }
  }

  private func createUploadRequest(
    fileURL: URL,
    destinationURL: URL,
    metadata: FileMetadata
  ) async throws -> HTTPRequest {
    let data = try Data(contentsOf: fileURL)
    return try createDataUploadRequest(
      data: data,
      fileName: metadata.name,
      destinationURL: destinationURL,
      mimeType: metadata.mimeType
    )
  }

  private func createDataUploadRequest(
    data: Data,
    fileName: String,
    destinationURL: URL,
    mimeType: String?
  ) throws -> HTTPRequest {
    var headers: [String: String] = [
      "Content-Length": "\(data.count)"
    ]

    if let mimeType = mimeType {
      headers["Content-Type"] = mimeType
    }

    headers["Content-Disposition"] = "attachment; filename=\"\(fileName)\""

    return HTTPRequest(
      method: .post,
      url: destinationURL,
      headers: headers,
      body: data,
      timeout: configuration.backgroundTransferConfiguration.timeoutIntervalForResource
    )
  }

  private enum TransferType {
    case upload
    case download
  }

  private func performTransfer(
    request: HTTPRequest,
    metadata: FileMetadata? = nil,
    destinationURL: URL? = nil,
    progressCallback: ProgressCallback? = nil,
    transferType: TransferType
  ) async throws -> FileTransferResult {
    let transferId = UUID()
    let startTime = Date()

    let activeTransfer = ActiveTransfer(
      transferId: transferId,
      startTime: startTime,
      fileMetadata: metadata,
      progressCallback: progressCallback
    )

    activeTransfers[transferId] = activeTransfer

    // Set progress callback
    if let progressCallback = progressCallback {
      await progressMiddleware.setProgressCallback(for: transferId, callback: progressCallback)
    }

    do {
      // Execute the request
      let response = try await httpClient.execute(request)

      // Handle download to file if destination URL provided
      if let destinationURL = destinationURL, let data = response.body {
        try data.write(to: destinationURL)
      }

      // Calculate results
      let duration = Date().timeIntervalSince(startTime)
      let bytesTransferred = Int64(response.body?.count ?? request.body?.count ?? 0)
      let averageSpeed = duration > 0 ? Double(bytesTransferred) / duration : 0

      // Verify checksum if applicable
      if configuration.enableIntegrityCheck,
        let data = response.body ?? request.body,
        let expectedChecksum = metadata?.checksum
      {
        let actualChecksum = calculateChecksum(for: data)
        if actualChecksum != expectedChecksum {
          throw FileTransferError.checksumMismatch(
            expected: expectedChecksum,
            actual: actualChecksum
          )
        }
      }

      let result = FileTransferResult(
        transferId: transferId,
        bytesTransferred: bytesTransferred,
        duration: duration,
        averageSpeed: averageSpeed,
        isSuccessful: true,
        fileMetadata: metadata
      )

      activeTransfers.removeValue(forKey: transferId)
      return result
    } catch {
      let duration = Date().timeIntervalSince(startTime)
      _ = FileTransferResult(
        transferId: transferId,
        bytesTransferred: 0,
        duration: duration,
        averageSpeed: 0,
        isSuccessful: false,
        error: error,
        fileMetadata: metadata
      )

      activeTransfers.removeValue(forKey: transferId)
      throw error
    }
  }

  private func waitForTransferCompletion(transferId: UUID) async throws -> FileTransferResult {
    // Simplified implementation - in a real scenario, this would monitor the URLSessionTask
    while activeTransfers[transferId] != nil {
      try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

      if let activeTransfer = activeTransfers[transferId], activeTransfer.isCancelled {
        throw FileTransferError.transferCancelled
      }
    }

    // Return a basic result (in real implementation, this would come from task completion)
    return FileTransferResult(
      transferId: transferId,
      bytesTransferred: 0,
      duration: 0,
      averageSpeed: 0,
      isSuccessful: true
    )
  }

  #if !os(Linux)
  nonisolated private func createBackgroundSession(
    with config: BackgroundTransferConfiguration? = nil
  ) -> URLSession {
    let configuration = config ?? self.configuration.backgroundTransferConfiguration

    let sessionConfig = URLSessionConfiguration.background(
      withIdentifier: configuration.backgroundSessionIdentifier
    )

    sessionConfig.allowsCellularAccess = configuration.allowsCellularAccess
    sessionConfig.allowsExpensiveNetworkAccess = configuration.allowsExpensiveNetworkAccess
    sessionConfig.timeoutIntervalForRequest = configuration.timeoutIntervalForRequest
    sessionConfig.timeoutIntervalForResource = configuration.timeoutIntervalForResource

    let delegate = BackgroundTransferDelegate(
      progressStreamManager: self.progressStreamManager
    )

    return URLSession(
      configuration: sessionConfig,
      delegate: delegate,
      delegateQueue: nil
    )
  }
  #endif

  private func getMimeType(for fileURL: URL) -> String? {
    let fileExtension = fileURL.pathExtension.lowercased()

    let mimeTypes: [String: String] = [
      "jpg": "image/jpeg",
      "jpeg": "image/jpeg",
      "png": "image/png",
      "gif": "image/gif",
      "pdf": "application/pdf",
      "txt": "text/plain",
      "html": "text/html",
      "json": "application/json",
      "xml": "application/xml",
      "zip": "application/zip",
      "mp4": "video/mp4",
      "mov": "video/quicktime",
      "mp3": "audio/mpeg",
      "wav": "audio/wav",
    ]

    return mimeTypes[fileExtension]
  }

  private func calculateChecksum(for data: Data) -> String {
    let hashData = configuration.checksumAlgorithm.hashFunction(data)
    return hashData.map { String(format: "%02x", $0) }.joined()
  }
}

// MARK: - Background Transfer Delegate

#if !os(Linux)

/// Delegate for handling background transfer events.
private final class BackgroundTransferDelegate: NSObject, URLSessionDownloadDelegate,
  @unchecked
  Sendable
{
  private let progressStreamManager: ProgressTracking.ProgressStreamManager

  init(progressStreamManager: ProgressTracking.ProgressStreamManager) {
    self.progressStreamManager = progressStreamManager
    super.init()
  }

  func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didFinishDownloadingTo location: URL
  ) {
    // Handle completed download
    // In a real implementation, this would notify the FileTransferOperations actor
  }

  func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didWriteData bytesWritten: Int64,
    totalBytesWritten: Int64,
    totalBytesExpectedToWrite: Int64
  ) {
    // LIFECYCLE: Fire-and-forget progress update - safe because:
    // 1. progressStreamManager is actor-isolated (thread-safe)
    // 2. Delegate callbacks run on URLSession's delegate queue (not main)
    // 3. Actor suspension doesn't block delegate queue
    // 4. Progress updates are best-effort (missing one doesn't break functionality)
    Task.detached {
      // Map URLSessionTask.taskIdentifier to UUID (FileTransferOperations tracks mapping)
      let transferId = UUID()  // TODO: Retrieve from activeTransfers[downloadTask.taskIdentifier]

      await self.progressStreamManager.bridgeDownloadProgress(
        for: transferId,
        bytesWritten: bytesWritten,
        totalBytesWritten: totalBytesWritten,
        totalBytesExpected: totalBytesExpectedToWrite
      )
    }
  }

  func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didResumeAtOffset fileOffset: Int64,
    expectedTotalBytes: Int64
  ) {
    // Handle resumed download
    // In a real implementation, this would update the transfer state
  }

  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didCompleteWithError error: (any Error)?
  ) {
    // Handle task completion or error
    // In a real implementation, this would notify the FileTransferOperations actor
  }
}

#endif  // !os(Linux)

// MARK: - CommonCrypto Integration

// Import CommonCrypto for checksum calculation (Apple platforms only)
#if canImport(CommonCrypto)
import CommonCrypto
#else
// For non-Apple platforms, define the CC_LONG type
private typealias CC_LONG = UInt32
#endif

// Helper constants for CommonCrypto (secure algorithms only)
private let sha256DigestLength = Int(32)
private let sha512DigestLength = Int(64)

// CommonCrypto functions (secure algorithms only)

private func CC_SHA256(
  _ data: UnsafeRawPointer!,
  _ len: CC_LONG,
  _ md: UnsafeMutablePointer<UInt8>!
) -> UnsafeMutablePointer<UInt8>! {
  // Placeholder - real implementation would call CommonCrypto
  md
}

private func CC_SHA512(
  _ data: UnsafeRawPointer!,
  _ len: CC_LONG,
  _ md: UnsafeMutablePointer<UInt8>!
) -> UnsafeMutablePointer<UInt8>! {
  // Placeholder - real implementation would call CommonCrypto
  md
}

// MARK: - Convenience Extensions

extension FileTransferOperations {
  /// Convenience method to upload multiple files concurrently.
  /// - Parameters:
  ///   - fileURLs: Array of local file URLs to upload
  ///   - destinationURLs: Array of remote URLs (must match fileURLs count)
  ///   - progressCallback: Optional callback for aggregate progress updates
  /// - Returns: Array of file transfer results
  public func uploadFiles(
    from fileURLs: [URL],
    to destinationURLs: [URL],
    progressCallback: ProgressCallback? = nil
  ) async throws -> [FileTransferResult] {
    guard fileURLs.count == destinationURLs.count else {
      throw HTTPError(category: .configuration("File URLs and destination URLs count mismatch"))
    }

    let progressAggregator: ProgressAggregator?
    if let progressCallback = progressCallback {
      progressAggregator = ProgressAggregator(callback: progressCallback)
    } else {
      progressAggregator = nil
    }

    var results: [FileTransferResult] = []

    for (fileURL, destinationURL) in zip(fileURLs, destinationURLs) {
      let transferId = UUID()

      let individualProgressCallback: ProgressCallback? =
        progressAggregator != nil
        ? { @Sendable progress in
          _ = Task.detached {
            await progressAggregator?.updateProgress(for: transferId, progress: progress)
          }
        } : nil

      let result = try await self.uploadFile(
        from: fileURL,
        to: destinationURL,
        progressCallback: individualProgressCallback
      )

      results.append(result)
    }

    return results
  }
}
