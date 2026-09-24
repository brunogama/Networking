// swiftlint:disable file_length
import Foundation
import NetworkingCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// swiftlint:disable type_body_length
/// Performs file uploads, downloads, and resumable transfers.
public actor FileTransferOperations {
  // MARK: - Properties

  private let httpClient: any HTTPClient
  private let configuration: FileTransferConfiguration
  private let fileInspector: FileTransferFileInspector
  private let backgroundTransfers: BackgroundTransferCoordinator

  private var backgroundSession: URLSession?

  // MARK: - Initialization

  /// Creates a file transfer service with the given HTTP client and configuration.
  public init(
    httpClient: any HTTPClient,
    configuration: FileTransferConfiguration = .default
  ) {
    self.httpClient = httpClient
    self.configuration = configuration
    self.fileInspector = FileTransferFileInspector(configuration: configuration)
    self.backgroundTransfers = BackgroundTransferCoordinator(configuration: configuration)

    #if !os(Linux)
    if configuration.backgroundTransferConfiguration.enableBackgroundTransfer.rawValue {
      self.backgroundSession = makeBackgroundTransferSession(
        transferConfiguration: configuration,
        backgroundConfiguration: configuration.backgroundTransferConfiguration,
        coordinator: backgroundTransfers
      )
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
  /// - Throws: A file validation or network error.
  public func uploadFile(
    from fileURL: LocalFileURL,
    to destinationURL: RemoteTransferURL,
    progressCallback: ProgressCallback? = nil
  ) async throws -> FileTransferResult {
    // Validate file
    let metadata = try await validateAndCreateMetadata(for: fileURL.rawValue)
    try validateFileTransfer(metadata: metadata)

    // Create request
    let request = createFileUploadRequest(
      destinationURL: destinationURL.rawValue,
      metadata: metadata
    )

    if let transferClient = httpClient as? any HTTPFileTransferClient,
      transferClient.canPerformNativeFileTransfer
    {
      return try await performFileUpload(
        client: transferClient,
        request: request,
        fileURL: fileURL.rawValue,
        metadata: metadata,
        progressCallback: progressCallback
      )
    }

    let data = try HTTPBody(Data(contentsOf: fileURL.rawValue))
    return try await performBufferedTransfer(
      request: createDataUploadRequest(
        data: data,
        fileName: metadata.name,
        destinationURL: destinationURL.rawValue,
        mimeType: metadata.mimeType
      ),
      direction: .upload,
      metadata: metadata,
      progressCallback: progressCallback
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
  /// - Throws: A file validation or network error.
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

    let request = createDataUploadRequest(
      data: data,
      fileName: fileName,
      destinationURL: destinationURL.rawValue,
      mimeType: mimeType
    )

    return try await performBufferedTransfer(
      request: request,
      direction: .upload,
      metadata: metadata,
      progressCallback: progressCallback
    )
  }

  // MARK: - File Download Operations

  /// Downloads a file from a remote URL to a local path.
  /// - Parameters:
  ///   - sourceURL: Remote URL to download from
  ///   - destinationURL: Local URL to save the file
  ///   - progressCallback: Optional callback for progress updates
  /// - Returns: File transfer result
  /// - Throws: A network or file error.
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

    if let transferClient = httpClient as? any HTTPFileTransferClient,
      transferClient.canPerformNativeDownload
    {
      return try await performFileDownload(
        client: transferClient,
        request: request,
        destinationURL: destinationURL.rawValue,
        progressCallback: progressCallback
      )
    }

    return try await performBufferedTransfer(
      request: request,
      direction: .download,
      destinationURL: destinationURL.rawValue,
      progressCallback: progressCallback
    )
  }

  /// Downloads a file and returns it as Data.
  /// - Parameters:
  ///   - sourceURL: Remote URL to download from
  ///   - progressCallback: Optional callback for progress updates
  /// - Returns: Downloaded file data and transfer result
  /// - Throws: A network or file error.
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

    if let transferClient = httpClient as? any HTTPFileTransferClient,
      transferClient.canPerformNativeDownload
    {
      return try await performDataDownload(
        client: transferClient,
        request: request,
        progressCallback: progressCallback
      )
    }

    let transfer = try await executeBufferedTransfer(
      request: request,
      direction: .download,
      progressCallback: progressCallback,
      destinationURL: nil
    )
    guard let data = transfer.response.body else {
      throw FileTransferError.fileNotFound(path: FileSystemPath(sourceURL.absoluteString))
    }

    return (data: data, result: transfer.result)
  }

  // MARK: - Resumable Transfer Operations

  /// Resumes a previously interrupted transfer.
  /// - Parameters:
  ///   - resumeData: Resume data from previous transfer
  ///   - progressCallback: Optional callback for progress updates
  /// - Returns: File transfer result
  /// - Throws: An invalid resume data, cancellation, or transfer error.
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
    let task = backgroundSession.downloadTask(withResumeData: resumeData.rawValue)

    return try await backgroundTransfers.resume(
      task: task,
      transferId: transferId,
      progressCallback: progressCallback
    )
  }

  /// Cancels an active transfer and returns resume data if available.
  /// - Parameter transferId: The ID of the transfer to cancel
  /// - Returns: Resume data for later resumption, if available
  public func cancelTransfer(_ transferId: TransferIdentifier) async -> TransferResumeData? {
    await backgroundTransfers.cancel(transferId)
  }

  // MARK: - Background Transfer Support

  /// Configures background transfer capabilities.
  /// - Parameter configuration: Background transfer configuration
  public func configureBackgroundTransfer(
    _ configuration: BackgroundTransferConfiguration
  ) async {
    #if !os(Linux)
    if configuration.enableBackgroundTransfer.rawValue {
      self.backgroundSession = makeBackgroundTransferSession(
        transferConfiguration: self.configuration,
        backgroundConfiguration: configuration,
        coordinator: backgroundTransfers
      )
    } else {
      self.backgroundSession?.invalidateAndCancel()
      self.backgroundSession = nil
    }
    #endif
  }

  // MARK: - Private Methods

  private func validateAndCreateMetadata(for fileURL: URL) async throws -> FileMetadata {
    try fileInspector.metadata(for: fileURL)
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

  private func createFileUploadRequest(
    destinationURL: URL,
    metadata: FileMetadata
  ) -> HTTPRequest {
    createUploadRequest(
      destinationURL: destinationURL,
      fileName: metadata.name,
      contentLength: metadata.size.rawValue,
      mimeType: metadata.mimeType,
      body: nil
    )
  }

  private func createDataUploadRequest(
    data: HTTPBody,
    fileName: FileName,
    destinationURL: URL,
    mimeType: HTTPMediaType?
  ) -> HTTPRequest {
    createUploadRequest(
      destinationURL: destinationURL,
      fileName: fileName,
      contentLength: Int64(data.count.rawValue),
      mimeType: mimeType,
      body: data
    )
  }

  // swiftlint:disable:next function_parameter_count
  private func createUploadRequest(
    destinationURL: URL,
    fileName: FileName,
    contentLength: Int64,
    mimeType: HTTPMediaType?,
    body: HTTPBody?
  ) -> HTTPRequest {
    var headers: [String: String] = [
      "Content-Length": "\(contentLength)"
    ]

    if let mimeType = mimeType {
      headers["Content-Type"] = mimeType.rawValue
    }

    headers["Content-Disposition"] = "attachment; filename=\"\(fileName.rawValue)\""

    return HTTPRequest(
      method: .post,
      url: HTTPRequestURL(destinationURL),
      headers: HTTPHeaders(headers),
      body: body,
      timeout: RequestTimeout(
        configuration.backgroundTransferConfiguration.timeoutIntervalForResource.rawValue
      )
    )
  }

  private enum TransferDirection: Sendable {
    case upload
    case download

    var activePhase: TransferPhase {
      switch self {
      case .upload:
        return .uploading
      case .download:
        return .downloading
      }
    }
  }

  private struct BufferedTransfer: Sendable {
    let response: HTTPResponse
    let result: FileTransferResult
  }

  private func performBufferedTransfer(
    request: HTTPRequest,
    direction: TransferDirection,
    metadata: FileMetadata? = nil,
    destinationURL: URL? = nil,
    progressCallback: ProgressCallback? = nil
  ) async throws -> FileTransferResult {
    try await executeBufferedTransfer(
      request: request,
      direction: direction,
      metadata: metadata,
      progressCallback: progressCallback,
      destinationURL: destinationURL
    ).result
  }

  private func executeBufferedTransfer(
    request: HTTPRequest,
    direction: TransferDirection,
    metadata: FileMetadata? = nil,
    progressCallback: ProgressCallback?,
    destinationURL: URL?
  ) async throws -> BufferedTransfer {
    let transferId = TransferIdentifier()
    let startTime = Date()

    do {
      let response = try await httpClient.execute(request)
      try write(response.body, to: destinationURL)

      let bytesTransferred: Int64
      switch direction {
      case .upload:
        bytesTransferred = Int64(request.body?.count.rawValue ?? 0)
      case .download:
        bytesTransferred = Int64(response.body?.count.rawValue ?? 0)
      }

      try validateChecksum(
        for: direction == .upload ? request.body : response.body,
        expectedChecksum: metadata?.checksum
      )

      let result = makeResult(
        transferId: transferId,
        startTime: startTime,
        bytesTransferred: bytesTransferred,
        metadata: metadata,
        destinationURL: destinationURL
      )
      reportCompletion(
        bytesTransferred: bytesTransferred,
        startTime: startTime,
        callback: progressCallback
      )
      return BufferedTransfer(response: response, result: result)
    } catch {
      reportFailure(callback: progressCallback)
      throw error
    }
  }

  // swiftlint:disable:next function_parameter_count
  private func performFileUpload(
    client: any HTTPFileTransferClient,
    request: HTTPRequest,
    fileURL: URL,
    metadata: FileMetadata,
    progressCallback: ProgressCallback?
  ) async throws -> FileTransferResult {
    let transferId = TransferIdentifier()
    let startTime = Date()
    let nativeProgress = makeNativeProgressCallback(
      direction: .upload,
      startTime: startTime,
      expectedBytes: metadata.size.rawValue,
      callback: progressCallback
    )

    do {
      _ = try await client.upload(request, fromFile: fileURL, progress: nativeProgress)
      let result = makeResult(
        transferId: transferId,
        startTime: startTime,
        bytesTransferred: metadata.size.rawValue,
        metadata: metadata,
        destinationURL: nil
      )
      reportCompletion(
        bytesTransferred: metadata.size.rawValue,
        startTime: startTime,
        callback: progressCallback
      )
      return result
    } catch {
      reportFailure(callback: progressCallback)
      throw error
    }
  }

  private func performFileDownload(
    client: any HTTPFileTransferClient,
    request: HTTPRequest,
    destinationURL: URL,
    progressCallback: ProgressCallback?
  ) async throws -> FileTransferResult {
    let transferId = TransferIdentifier()
    let startTime = Date()
    let nativeProgress = makeNativeProgressCallback(
      direction: .download,
      startTime: startTime,
      expectedBytes: nil,
      callback: progressCallback
    )

    do {
      let download = try await client.download(request, progress: nativeProgress)
      defer { try? FileManager.default.removeItem(at: download.temporaryFileURL) }
      try installDownloadedFile(from: download.temporaryFileURL, to: destinationURL)
      let bytesTransferred = try fileSize(at: destinationURL)
      let result = makeResult(
        transferId: transferId,
        startTime: startTime,
        bytesTransferred: bytesTransferred,
        metadata: nil,
        destinationURL: destinationURL
      )
      reportCompletion(
        bytesTransferred: bytesTransferred,
        startTime: startTime,
        callback: progressCallback
      )
      return result
    } catch {
      reportFailure(callback: progressCallback)
      throw error
    }
  }

  private func performDataDownload(
    client: any HTTPFileTransferClient,
    request: HTTPRequest,
    progressCallback: ProgressCallback?
  ) async throws -> (data: HTTPBody, result: FileTransferResult) {
    let transferId = TransferIdentifier()
    let startTime = Date()
    let nativeProgress = makeNativeProgressCallback(
      direction: .download,
      startTime: startTime,
      expectedBytes: nil,
      callback: progressCallback
    )

    do {
      let download = try await client.download(request, progress: nativeProgress)
      defer { try? FileManager.default.removeItem(at: download.temporaryFileURL) }
      let data = HTTPBody(try Data(contentsOf: download.temporaryFileURL))
      let bytesTransferred = Int64(data.count.rawValue)
      let result = makeResult(
        transferId: transferId,
        startTime: startTime,
        bytesTransferred: bytesTransferred,
        metadata: nil,
        destinationURL: nil
      )
      reportCompletion(
        bytesTransferred: bytesTransferred,
        startTime: startTime,
        callback: progressCallback
      )
      return (data, result)
    } catch {
      reportFailure(callback: progressCallback)
      throw error
    }
  }

  private func makeNativeProgressCallback(
    direction: TransferDirection,
    startTime: Date,
    expectedBytes: Int64?,
    callback: ProgressCallback?
  ) -> (@Sendable (HTTPFileTransferProgress) -> Void)? {
    guard let callback else { return nil }

    return { progress in
      let duration = Date().timeIntervalSince(startTime)
      let speed = duration > 0 ? Double(progress.transferredBytes) / duration : 0
      callback(
        TransferProgress(
          totalBytes: (progress.totalBytes ?? expectedBytes).map {
            TransferByteCount(rawValue: $0)
          },
          transferredBytes: TransferByteCount(progress.transferredBytes),
          phase: direction.activePhase,
          bytesPerSecond: TransferSpeed(speed)
        )
      )
    }
  }

  // swiftlint:disable:next function_parameter_count
  private func makeResult(
    transferId: TransferIdentifier,
    startTime: Date,
    bytesTransferred: Int64,
    metadata: FileMetadata?,
    destinationURL: URL?
  ) -> FileTransferResult {
    let duration = Date().timeIntervalSince(startTime)
    let averageSpeed = duration > 0 ? Double(bytesTransferred) / duration : 0
    return FileTransferResult(
      transferId: transferId,
      bytesTransferred: TransferByteCount(bytesTransferred),
      duration: TransferDuration(duration),
      averageSpeed: TransferSpeed(averageSpeed),
      isSuccessful: true,
      fileMetadata: metadata,
      fileURL: destinationURL.map { LocalFileURL($0) }
    )
  }

  private func reportCompletion(
    bytesTransferred: Int64,
    startTime: Date,
    callback: ProgressCallback?
  ) {
    guard let callback else { return }
    let duration = Date().timeIntervalSince(startTime)
    let averageSpeed = duration > 0 ? Double(bytesTransferred) / duration : 0
    callback(
      TransferProgress(
        totalBytes: TransferByteCount(bytesTransferred),
        transferredBytes: TransferByteCount(bytesTransferred),
        phase: .completed,
        bytesPerSecond: TransferSpeed(averageSpeed)
      )
    )
  }

  private func reportFailure(callback: ProgressCallback?) {
    callback?(
      TransferProgress(
        totalBytes: nil,
        transferredBytes: 0,
        phase: .failed
      )
    )
  }

  private func write(_ data: HTTPBody?, to destinationURL: URL?) throws {
    guard let destinationURL else { return }
    guard let data else {
      throw FileTransferError.fileNotFound(path: FileSystemPath(destinationURL.path))
    }
    try data.write(to: destinationURL)
  }

  private func installDownloadedFile(from temporaryURL: URL, to destinationURL: URL) throws {
    let fileManager = FileManager.default
    let stagingURL = destinationURL.deletingLastPathComponent().appendingPathComponent(
      ".\(UUID().uuidString)-\(destinationURL.lastPathComponent)"
    )
    defer { try? fileManager.removeItem(at: stagingURL) }

    try fileManager.copyItem(at: temporaryURL, to: stagingURL)
    if fileManager.fileExists(atPath: destinationURL.path) {
      _ = try fileManager.replaceItemAt(destinationURL, withItemAt: stagingURL)
    } else {
      try fileManager.moveItem(at: stagingURL, to: destinationURL)
    }
    try? fileManager.removeItem(at: temporaryURL)
  }

  private func fileSize(at fileURL: URL) throws -> Int64 {
    let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
    return (attributes[.size] as? NSNumber)?.int64Value ?? 0
  }

  private func validateChecksum(
    for data: HTTPBody?,
    expectedChecksum: FileChecksum?
  ) throws {
    guard configuration.enableIntegrityCheck.rawValue,
      let data,
      let expectedChecksum
    else {
      return
    }

    let actualChecksum = calculateChecksum(for: data)
    guard actualChecksum == expectedChecksum else {
      throw FileTransferError.checksumMismatch(
        expected: expectedChecksum,
        actual: actualChecksum
      )
    }
  }

  private func calculateChecksum(for data: HTTPBody) -> FileChecksum {
    let hashData = configuration.checksumAlgorithm.hash(data)
    return FileChecksum(hashData.rawValue.map { String(format: "%02x", $0) }.joined())
  }
}
// swiftlint:enable type_body_length
