import NetworkingCore

#if canImport(OSLog)
import os

extension LoggingMiddleware {
  // MARK: - Configuration

  /// Controls unified logging and optional header and body capture.
  public struct Configuration: Sendable {

    public let subsystem: LoggingSubsystemName

    public let category: LoggingCategoryName

    public let logLevel: os.OSLogType

    public let logHeaders: CollectHeadersFlag

    public let logBody: CollectBodyInfoFlag

    public let maxBodyLength: LogBodyLengthLimit

    public init(
      subsystem: LoggingSubsystemName = "Networking",
      category: LoggingCategoryName = "HTTPClient",
      logLevel: os.OSLogType = .debug,
      logHeaders: CollectHeadersFlag = true,
      logBody: CollectBodyInfoFlag = false,
      maxBodyLength: LogBodyLengthLimit = 1024
    ) {
      self.subsystem = subsystem
      self.category = category
      self.logLevel = logLevel
      self.logHeaders = logHeaders
      self.logBody = logBody
      self.maxBodyLength = maxBodyLength
    }
  }
}
#endif
