import NetworkingCore

/// Configuration for file transfer operations.
public struct FileTransferConfiguration: Sendable {
  /// Maximum file size allowed for transfer.
  public let maxFileSize: FileSize

  /// Supported MIME types (nil means all types are supported).
  public let supportedMimeTypes: Set<HTTPMediaType>?

  /// Whether to enable file integrity checking.
  public let enableIntegrityCheck: FileIntegrityCheckFlag

  /// Checksum algorithm to use for integrity checking.
  public let checksumAlgorithm: ChecksumAlgorithm

  /// Whether to allow resumable transfers.
  public let allowResumableTransfers: ResumableTransferFlag

  /// Directory for temporary files during transfer.
  public let temporaryDirectory: TemporaryDirectoryURL?

  /// Background transfer configuration.
  public let backgroundTransferConfiguration: BackgroundTransferConfiguration

  /// Configures transfer size, integrity, and native background operations.
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

  /// Allows files up to 500 MiB with SHA-256 integrity checks.
  public static let `default` = Self()
}
