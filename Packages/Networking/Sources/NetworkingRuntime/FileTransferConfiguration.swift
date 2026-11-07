import NetworkingCore

/// Configuration for file transfer operations.
public struct FileTransferConfiguration: Sendable {

  public let maxFileSize: FileSize

  public let supportedMimeTypes: Set<HTTPMediaType>?

  public let enableIntegrityCheck: FileIntegrityCheckFlag

  public let checksumAlgorithm: ChecksumAlgorithm

  public let allowResumableTransfers: ResumableTransferFlag

  public let temporaryDirectory: TemporaryDirectoryURL?

  public let backgroundTransferConfiguration: BackgroundTransferConfiguration

  public init(
    maxFileSize: FileSize = FileSize(524_288_000),  // 500MB
    supportedMimeTypes: Set<HTTPMediaType>? = nil,
    enableIntegrityCheck: FileIntegrityCheckFlag = true,
    checksumAlgorithm: ChecksumAlgorithm = .sha256,
    allowResumableTransfers: ResumableTransferFlag = true,
    temporaryDirectory: TemporaryDirectoryURL? = nil,
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
