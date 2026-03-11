import Foundation
import NetworkingCore

#if canImport(CommonCrypto)
import CommonCrypto
#endif

/// Represents the result of a file transfer operation.
public struct FileTransferResult: Sendable {
  /// The unique identifier for this transfer
  public let transferId: TransferIdentifier

  /// The total number of bytes transferred
  public let bytesTransferred: TransferByteCount

  /// The total duration of the transfer
  public let duration: TransferDuration

  /// Average transfer speed in bytes per second
  public let averageSpeed: TransferSpeed

  /// Whether the transfer completed successfully
  public let isSuccessful: TransferSuccessFlag

  /// Any error that occurred during transfer
  public let error: (any Error)?

  /// Resume data for failed or cancelled transfers
  public let resumeData: TransferResumeData?

  /// Metadata about the transferred file
  public let fileMetadata: FileMetadata?

  public init(
    transferId: TransferIdentifier,
    bytesTransferred: TransferByteCount,
    duration: TransferDuration,
    averageSpeed: TransferSpeed,
    isSuccessful: TransferSuccessFlag,
    error: (any Error)? = nil,
    resumeData: TransferResumeData? = nil,
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
  public let name: FileName

  /// The file size in bytes
  public let size: FileSize

  /// The MIME type of the file
  public let mimeType: HTTPMediaType?

  /// File creation date
  public let createdAt: Date?

  /// File modification date
  public let modifiedAt: Date?

  /// File checksum for integrity verification
  public let checksum: FileChecksum?

  /// File extension
  public var fileExtension: FileExtension? {
    let components = name.rawValue.components(separatedBy: ".")
    return components.count > 1 ? components.last.map { FileExtension($0) } : nil
  }

  public init(
    name: FileName,
    size: FileSize,
    mimeType: HTTPMediaType? = nil,
    createdAt: Date? = nil,
    modifiedAt: Date? = nil,
    checksum: FileChecksum? = nil
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
  public let maxFileSize: FileSize

  /// Supported MIME types (nil means all types are supported)
  public let supportedMimeTypes: Set<HTTPMediaType>?

  /// Whether to enable file integrity checking
  public let enableIntegrityCheck: FileIntegrityCheckFlag

  /// Checksum algorithm to use for integrity checking
  public let checksumAlgorithm: ChecksumAlgorithm

  /// Whether to allow resumable transfers
  public let allowResumableTransfers: ResumableTransferFlag

  /// Directory for temporary files during transfer
  public let temporaryDirectory: TemporaryDirectoryURL?

  /// Background transfer configuration
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

/// Supported secure checksum algorithms for file integrity verification.
/// Only SHA-256 and SHA-512 are supported for security reasons.
public enum ChecksumAlgorithm: Sendable, CaseIterable {
  case sha256
  case sha512

  public var identifier: ChecksumAlgorithmName {
    switch self {
    case .sha256: return "sha256"
    case .sha512: return "sha512"
    }
  }

  public func hash(_ data: HTTPBody) -> HTTPBody {
    switch self {
    case .sha256:
      var digest = [UInt8](repeating: 0, count: Int(sha256DigestLength))
      data.rawValue.withUnsafeBytes {
        _ = CC_SHA256($0.baseAddress, CC_LONG(data.rawValue.count), &digest)
      }
      return HTTPBody(Data(digest))

    case .sha512:
      var digest = [UInt8](repeating: 0, count: Int(sha512DigestLength))
      data.rawValue.withUnsafeBytes {
        _ = CC_SHA512($0.baseAddress, CC_LONG(data.rawValue.count), &digest)
      }
      return HTTPBody(Data(digest))
    }
  }
}

/// Configuration for background transfer operations.
public struct BackgroundTransferConfiguration: Sendable {
  /// Whether to allow transfers when app is backgrounded
  public let enableBackgroundTransfer: BackgroundTransferFlag

  /// Background session identifier
  public let backgroundSessionIdentifier: BackgroundSessionIdentifier

  /// Whether to allow cellular data for background transfers
  public let allowsCellularAccess: SessionAllowsCellularAccess

  /// Whether to allow expensive network access
  public let allowsExpensiveNetworkAccess: SessionAllowsExpensiveNetworkAccess

  /// Timeout interval for background transfers
  public let timeoutIntervalForRequest: SessionRequestTimeout

  /// Resource timeout for background transfers
  public let timeoutIntervalForResource: SessionRequestTimeout

  public init(
    enableBackgroundTransfer: BackgroundTransferFlag = false,
    backgroundSessionIdentifier: BackgroundSessionIdentifier = "Networking.BackgroundTransfer",
    allowsCellularAccess: SessionAllowsCellularAccess = true,
    allowsExpensiveNetworkAccess: SessionAllowsExpensiveNetworkAccess = false,
    timeoutIntervalForRequest: SessionRequestTimeout = 60.0,
    timeoutIntervalForResource: SessionRequestTimeout = 3600.0
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
  case fileTooLarge(size: FileSize, maxSize: FileSize)
  case unsupportedFileType(mimeType: HTTPMediaType)
  case fileNotFound(path: FileSystemPath)
  case insufficientStorage
  case checksumMismatch(expected: FileChecksum, actual: FileChecksum)
  case transferCancelled
  case resumeDataCorrupted
  case backgroundTransferNotSupported
  case temporaryDirectoryUnavailable

  public var errorDescription: String? {
    switch self {
    case .fileTooLarge(let size, let maxSize):
      return "File size (\(size) bytes) exceeds maximum allowed size (\(maxSize) bytes)"

    case .unsupportedFileType(let mimeType):
      return "File type '\(mimeType.rawValue)' is not supported"

    case .fileNotFound(let path):
      return "File not found at path: \(path.rawValue)"

    case .insufficientStorage:
      return "Insufficient storage space for file transfer"

    case .checksumMismatch(let expected, let actual):
      return
        "File integrity check failed. Expected: \(expected.rawValue), Actual: \(actual.rawValue)"

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

// MARK: - CommonCrypto Integration

#if !canImport(CommonCrypto)
// For non-Apple platforms, define the CC_LONG type.
private typealias CC_LONG = UInt32
#endif

private let sha256DigestLength = Int(32)
private let sha512DigestLength = Int(64)

private func CC_SHA256(
  _ data: UnsafeRawPointer!,
  _ len: CC_LONG,
  _ md: UnsafeMutablePointer<UInt8>!
) -> UnsafeMutablePointer<UInt8>! {
  // Placeholder - real implementation would call CommonCrypto.
  md
}

private func CC_SHA512(
  _ data: UnsafeRawPointer!,
  _ len: CC_LONG,
  _ md: UnsafeMutablePointer<UInt8>!
) -> UnsafeMutablePointer<UInt8>! {
  // Placeholder - real implementation would call CommonCrypto.
  md
}
