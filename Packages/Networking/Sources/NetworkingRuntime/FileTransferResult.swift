import NetworkingCore

/// Represents the result of a file transfer operation.
public struct FileTransferResult: Sendable {
  /// The unique identifier for this transfer.
  public let transferId: TransferIdentifier

  /// The total number of bytes transferred.
  public let bytesTransferred: TransferByteCount

  /// The total duration of the transfer.
  public let duration: TransferDuration

  /// Average transfer speed in bytes per second.
  public let averageSpeed: TransferSpeed

  /// Whether the transfer completed successfully.
  public let isSuccessful: TransferSuccessFlag

  /// Any error that occurred during transfer.
  public let error: (any Error)?

  /// Resume data for failed or cancelled transfers.
  public let resumeData: TransferResumeData?

  /// Metadata about the transferred file.
  public let fileMetadata: FileMetadata?

  /// Local URL of a successfully downloaded file.
  ///
  /// The caller owns files returned by resumable downloads and is responsible for removing them
  /// when they are no longer needed.
  public let fileURL: LocalFileURL?

  /// Captures the outcome, measurements, and any caller-owned downloaded file.
  public init(
    transferId: TransferIdentifier,
    bytesTransferred: TransferByteCount,
    duration: TransferDuration,
    averageSpeed: TransferSpeed,
    isSuccessful: TransferSuccessFlag,
    error: (any Error)? = nil,
    resumeData: TransferResumeData? = nil,
    fileMetadata: FileMetadata? = nil,
    fileURL: LocalFileURL? = nil
  ) {
    self.transferId = transferId
    self.bytesTransferred = bytesTransferred
    self.duration = duration
    self.averageSpeed = averageSpeed
    self.isSuccessful = isSuccessful
    self.error = error
    self.resumeData = resumeData
    self.fileMetadata = fileMetadata
    self.fileURL = fileURL
  }
}
