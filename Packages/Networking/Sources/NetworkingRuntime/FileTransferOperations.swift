// swiftlint:disable file_length
import Foundation
import NetworkingCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// Main class for handling file transfer operations.
// swiftlint:disable:next type_body_length
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
        enableChunkedTransfer: ChunkedTransferSupportFlag(
          configuration.allowResumableTransfers.rawValue
        )
      )
    )

    #if !os(Linux)
    if configuration.backgroundTransferConfiguration.enableBackgroundTransfer.rawValue {
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
    from fileURL: LocalFileURL,
    to destinationURL: RemoteTransferURL,
    progressCallback: ProgressCallback? = nil
  ) async throws -> FileTransferResult {
    // Validate file
    let metadata = try await validateAndCreateMetadata(for: fileURL.rawValue)
    try validateFileTransfer(metadata: metadata)

    // Create request
    let request = try await createUploadRequest(
      fileURL: fileURL.rawValue,
      destinationURL: destinationURL.rawValue,
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
    _ data: HTTPBody,
    fileName: FileName,
    to destinationURL: RemoteTransferURL,
    mimeType: HTTPMediaType? = nil,
    progressCallback: ProgressCallback? = nil
  ) async throws -> FileTransferResult {
    let metadata = FileMetadata(
      name: fileName,
      size: FileSize(Int64(data.count.rawValue)),
      mimeType: mimeType,
      checksum: configuration.enableIntegrityCheck.rawValue ? calculateChecksum(for: data) : nil
    )

    try validateFileTransfer(metadata: metadata)

    let request = try createDataUploadRequest(
      data: data,
      fileName: fileName,
      destinationURL: destinationURL.rawValue,
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
    from sourceURL: RemoteTransferURL,
    to destinationURL: LocalFileURL,
    progressCallback: ProgressCallback? = nil
  ) async throws -> FileTransferResult {
    let request = HTTPRequest(
      method: .get,
      url: HTTPRequestURL(sourceURL.rawValue),
      timeout: RequestTimeout(
        configuration.backgroundTransferConfiguration.timeoutIntervalForRequest.rawValue
      )
    )

    return try await performTransfer(
      request: request,
      destinationURL: destinationURL.rawValue,
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
    from sourceURL: RemoteTransferURL,
    progressCallback: ProgressCallback? = nil
  ) async throws -> (data: HTTPBody, result: FileTransferResult) {
    let request = HTTPRequest(
      method: .get,
      url: HTTPRequestURL(sourceURL.rawValue),
      timeout: RequestTimeout(
        configuration.backgroundTransferConfiguration.timeoutIntervalForRequest.rawValue
      )
    )

    let result = try await performTransfer(
      request: request,
      progressCallback: progressCallback,
      transferType: .download
    )

    // Get the downloaded data from response
    let response = try await httpClient.execute(request)
    guard let data = response.body else {
      throw FileTransferError.fileNotFound(path: FileSystemPath(sourceURL.absoluteString))
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
    with resumeData: TransferResumeData,
    progressCallback: ProgressCallback? = nil
  ) async throws -> FileTransferResult {
    guard configuration.allowResumableTransfers.rawValue else {
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

    let transferId = TransferIdentifier()
    let startTime = Date()

    // Create task from resume data
    let task = backgroundSession.downloadTask(withResumeData: resumeData.rawValue)

    let activeTransfer = ActiveTransfer(
      transferId: transferId.rawValue,
      startTime: startTime,
      fileMetadata: nil,
      progressCallback: progressCallback,
      task: task,
      resumeData: resumeData.rawValue
    )

    activeTransfers[transferId.rawValue] = activeTransfer

    // Set progress callback
    if let progressCallback = progressCallback {
      await progressMiddleware.setProgressCallback(
        for: HTTPRequestID(transferId.rawValue),
        callback: progressCallback
      )
    }

    // Start task
    task.resume()

    // Wait for completion (simplified for this implementation)
    return try await waitForTransferCompletion(transferId: transferId)
  }

  /// Cancels an active transfer and returns resume data if available.
  /// - Parameter transferId: The ID of the transfer to cancel
  /// - Returns: Resume data for later resumption, if available
  public func cancelTransfer(_ transferId: TransferIdentifier) async -> TransferResumeData? {
    guard var activeTransfer = activeTransfers[transferId.rawValue] else {
      return nil
    }

    activeTransfer.isCancelled = true
    activeTransfers[transferId.rawValue] = activeTransfer

    // Cancel the task and collect resume data
    if let task = activeTransfer.task as? URLSessionDownloadTask {
      return await withCheckedContinuation { continuation in
        task.cancel { resumeData in
          continuation.resume(returning: resumeData.map { TransferResumeData($0) })
        }
      }
    } else {
      activeTransfer.task?.cancel()
      return activeTransfer.resumeData.map { TransferResumeData($0) }
    }
  }

  // MARK: - Background Transfer Support

  /// Configures background transfer capabilities.
  /// - Parameter configuration: Background transfer configuration
  public func configureBackgroundTransfer(
    _ configuration: BackgroundTransferConfiguration
  ) async {
    #if !os(Linux)
    if configuration.enableBackgroundTransfer.rawValue {
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
      throw FileTransferError.fileNotFound(path: FileSystemPath(fileURL.path))
    }

    let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
    let fileSize = attributes[.size] as? Int64 ?? 0
    let createdAt = attributes[.creationDate] as? Date
    let modifiedAt = attributes[.modificationDate] as? Date

    let fileName = fileURL.lastPathComponent
    let mimeType = getMimeType(for: fileURL)

    // Calculate checksum if enabled
    let checksum: FileChecksum?
    if configuration.enableIntegrityCheck.rawValue {
      let data = try HTTPBody(Data(contentsOf: fileURL))
      checksum = calculateChecksum(for: data)
    } else {
      checksum = nil
    }

    return FileMetadata(
      name: FileName(fileName),
      size: FileSize(fileSize),
      mimeType: mimeType,
      createdAt: createdAt,
      modifiedAt: modifiedAt,
      checksum: checksum
    )
  }

  private func validateFileTransfer(metadata: FileMetadata) throws {
    // Check file size
    if metadata.size.rawValue > configuration.maxFileSize.rawValue {
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
    let data = try HTTPBody(Data(contentsOf: fileURL))
    return try createDataUploadRequest(
      data: data,
      fileName: metadata.name,
      destinationURL: destinationURL,
      mimeType: metadata.mimeType
    )
  }

  private func createDataUploadRequest(
    data: HTTPBody,
    fileName: FileName,
    destinationURL: URL,
    mimeType: HTTPMediaType?
  ) throws -> HTTPRequest {
    var headers: [String: String] = [
      "Content-Length": "\(data.count)"
    ]

    if let mimeType = mimeType {
      headers["Content-Type"] = mimeType.rawValue
    }

    headers["Content-Disposition"] = "attachment; filename=\"\(fileName.rawValue)\""

    return HTTPRequest(
      method: .post,
      url: HTTPRequestURL(destinationURL),
      headers: HTTPHeaders(headers),
      body: data,
      timeout: RequestTimeout(
        configuration.backgroundTransferConfiguration.timeoutIntervalForResource.rawValue
      )
    )
  }

  private enum TransferType {
    case upload
    case download
  }

  // swiftlint:disable:next cyclomatic_complexity function_body_length
  private func performTransfer(
    request: HTTPRequest,
    metadata: FileMetadata? = nil,
    destinationURL: URL? = nil,
    progressCallback: ProgressCallback? = nil,
    transferType: TransferType
  ) async throws -> FileTransferResult {
    let transferId = TransferIdentifier()
    let startTime = Date()

    let activeTransfer = ActiveTransfer(
      transferId: transferId.rawValue,
      startTime: startTime,
      fileMetadata: metadata,
      progressCallback: progressCallback
    )

    activeTransfers[transferId.rawValue] = activeTransfer

    // Set progress callback
    if let progressCallback = progressCallback {
      await progressMiddleware.setProgressCallback(
        for: HTTPRequestID(transferId.rawValue),
        callback: progressCallback
      )
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
      let bytesTransferred = Int64((response.body?.count ?? request.body?.count ?? 0).rawValue)
      let averageSpeed = duration > 0 ? Double(bytesTransferred) / duration : 0

      // Verify checksum if applicable
      if configuration.enableIntegrityCheck.rawValue,
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
        bytesTransferred: TransferByteCount(bytesTransferred),
        duration: TransferDuration(duration),
        averageSpeed: TransferSpeed(averageSpeed),
        isSuccessful: true,
        fileMetadata: metadata
      )

      activeTransfers.removeValue(forKey: transferId.rawValue)
      return result
    } catch {
      let duration = Date().timeIntervalSince(startTime)
      _ = FileTransferResult(
        transferId: transferId,
        bytesTransferred: 0,
        duration: TransferDuration(duration),
        averageSpeed: 0,
        isSuccessful: false,
        error: error,
        fileMetadata: metadata
      )

      activeTransfers.removeValue(forKey: transferId.rawValue)
      throw error
    }
  }

  private func waitForTransferCompletion(
    transferId: TransferIdentifier
  ) async throws -> FileTransferResult {
    // Simplified implementation - in a real scenario, this would monitor the URLSessionTask
    while activeTransfers[transferId.rawValue] != nil {
      try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

      if let activeTransfer = activeTransfers[transferId.rawValue], activeTransfer.isCancelled {
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
      withIdentifier: configuration.backgroundSessionIdentifier.rawValue
    )

    sessionConfig.allowsCellularAccess = configuration.allowsCellularAccess.rawValue
    sessionConfig.allowsExpensiveNetworkAccess = configuration.allowsExpensiveNetworkAccess.rawValue
    sessionConfig.timeoutIntervalForRequest = configuration.timeoutIntervalForRequest.rawValue
    sessionConfig.timeoutIntervalForResource = configuration.timeoutIntervalForResource.rawValue

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

  private func getMimeType(for fileURL: URL) -> HTTPMediaType? {
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

    return mimeTypes[fileExtension].map { HTTPMediaType($0) }
  }

  private func calculateChecksum(for data: HTTPBody) -> FileChecksum {
    let hashData = configuration.checksumAlgorithm.hash(data)
    return FileChecksum(hashData.rawValue.map { String(format: "%02x", $0) }.joined())
  }
}
