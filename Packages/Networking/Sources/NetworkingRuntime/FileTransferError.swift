import Foundation
import NetworkingCore

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
