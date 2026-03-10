import Foundation
import NetworkingCore

extension ProgressTracking {
  /// Specialized progress tracker for file operations
  public struct FileOperationProgressTracker: Sendable {
    /// File operation types
    public enum OperationType: Sendable {
      case upload(source: LocalFileURL, destination: RemoteTransferURL)
      case download(source: RemoteTransferURL, destination: LocalFileURL)
      case copy(source: LocalFileURL, destination: LocalFileURL)
      case move(source: LocalFileURL, destination: LocalFileURL)

      public var description: FileOperationDescription {
        switch self {
        case .upload(let source, let destination):
          return FileOperationDescription(
            "Uploading \(source.lastPathComponent) to \(destination.absoluteString)"
          )

        case .download(let source, let destination):
          return FileOperationDescription(
            "Downloading \(source.lastPathComponent) to \(destination.lastPathComponent)"
          )

        case .copy(let source, let destination):
          return FileOperationDescription(
            "Copying \(source.lastPathComponent) to \(destination.lastPathComponent)"
          )

        case .move(let source, let destination):
          return FileOperationDescription(
            "Moving \(source.lastPathComponent) to \(destination.lastPathComponent)"
          )
        }
      }
    }

    /// Creates a progress stream for a file operation
    /// - Parameters:
    ///   - operation: Type of file operation
    ///   - streamManager: Progress stream manager to use
    /// - Returns: Tuple containing transfer ID and progress stream
    public static func trackFileOperation(
      _ operation: OperationType,
      using streamManager: ProgressStreamManager
    ) async -> (
      transferId: TransferIdentifier,
      stream: AsyncThrowingStream<ProgressUpdate, any Error>
    ) {
      let transferId = TransferIdentifier()
      let totalBytes = getTotalBytes(for: operation)

      let stream = await streamManager.createProgressStream(
        for: transferId,
        totalBytes: totalBytes
      )

      return (transferId, stream)
    }

    private static func getTotalBytes(for operation: OperationType) -> TransferByteCount? {
      switch operation {
      case .upload(let source, _), .copy(let source, _), .move(let source, _):
        return getFileSize(at: source)

      case .download:
        return nil  // Unknown until we start downloading
      }
    }

    private static func getFileSize(at url: LocalFileURL) -> TransferByteCount? {
      do {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? Int64 else {
          return nil
        }
        return TransferByteCount(size)
      } catch {
        return nil
      }
    }
  }
}
