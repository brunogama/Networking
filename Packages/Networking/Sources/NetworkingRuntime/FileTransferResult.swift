import NetworkingCore

/// Represents the result of a file transfer operation.
public struct FileTransferResult: Sendable {

  public let transferId: TransferIdentifier

  public let bytesTransferred: TransferByteCount

  public let duration: TransferDuration

  public let averageSpeed: TransferSpeed

  public let isSuccessful: TransferSuccessFlag

  public let error: (any Error)?

  public let resumeData: TransferResumeData?

  public let fileMetadata: FileMetadata?

  public let fileURL: LocalFileURL?

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
