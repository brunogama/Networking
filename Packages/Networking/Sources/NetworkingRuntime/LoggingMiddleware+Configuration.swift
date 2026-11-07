import NetworkingCore

#if canImport(OSLog)
import OSLog

extension LoggingMiddleware {
  // MARK: - Configuration

  /// Controls unified logging and optional header and body capture.
  public struct Configuration: Sendable {
    /// Unified logging subsystem.
    public let subsystem: LoggingSubsystemName
    /// Unified logging category.
    public let category: LoggingCategoryName
    /// Log level for request and response messages.
    public let logLevel: OSLogType
    /// Whether to include headers in log messages.
    public let logHeaders: CollectHeadersFlag
    /// Whether to include a bounded body prefix in log messages.
    public let logBody: CollectBodyInfoFlag
    /// Maximum characters retained from a decoded body.
    public let maxBodyLength: LogBodyLengthLimit

    /// Selects log destinations and content capture settings.
    public init(
      subsystem: LoggingSubsystemName = "Networking",
      category: LoggingCategoryName = "HTTPClient",
      logLevel: OSLogType = .debug,
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
