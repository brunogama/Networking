import Foundation
import NetworkingCore

#if canImport(OSLog)
import OSLog

/// Middleware that logs HTTP requests and responses using OSLog.
public struct LoggingMiddleware: HTTPRequestMiddleware, HTTPResponseMiddleware, HTTPErrorMiddleware
{
  // MARK: - Configuration

  public struct Configuration: Sendable {
    public let subsystem: LoggingSubsystemName
    public let category: LoggingCategoryName
    public let logLevel: OSLogType
    public let logHeaders: CollectHeadersFlag
    public let logBody: CollectBodyInfoFlag
    public let maxBodyLength: LogBodyLengthLimit

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

  // MARK: - Properties

  private let configuration: Configuration
  private let logger: Logger

  // MARK: - Initialization

  public init(configuration: Configuration = Configuration()) {
    self.configuration = configuration
    self.logger = Logger(
      subsystem: configuration.subsystem.rawValue,
      category: configuration.category.rawValue
    )
  }
  // MARK: - HTTPRequestMiddleware

  public func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
    logger.log(
      level: configuration.logLevel,
      "→ \(request.method.rawValue) \(request.url.absoluteString)"
    )

    if configuration.logHeaders.rawValue && !request.headers.isEmpty {
      logger.log(
        level: configuration.logLevel,
        "  Headers: \(request.headers.description)"
      )
    }

    if configuration.logBody.rawValue,
      let body = request.body,
      let bodyString = String(data: body.rawValue, encoding: .utf8)
    {
      let truncatedBody = String(bodyString.prefix(configuration.maxBodyLength.rawValue))
      logger.log(
        level: configuration.logLevel,
        "  Body: \(truncatedBody)"
      )
    }

    return request
  }

  // MARK: - HTTPResponseMiddleware

  public func processResponse(
    _ response: HTTPResponse,
    for request: HTTPRequest
  ) async throws -> HTTPResponse {
    logger.log(
      level: configuration.logLevel,
      "← \(response.status.rawValue) \(request.method.rawValue) \(request.url.absoluteString)"
    )

    if configuration.logHeaders.rawValue && !response.headers.isEmpty {
      logger.log(
        level: configuration.logLevel,
        "  Headers: \(response.headers.description)"
      )
    }

    if configuration.logBody.rawValue,
      let body = response.body,
      let bodyString = String(data: body.rawValue, encoding: .utf8)
    {
      let truncatedBody = String(bodyString.prefix(configuration.maxBodyLength.rawValue))
      logger.log(
        level: configuration.logLevel,
        "  Body: \(truncatedBody)"
      )
    }

    return response
  }
  // MARK: - HTTPErrorMiddleware

  public func handleError(
    _ error: HTTPError,
    for request: HTTPRequest
  ) async throws -> HTTPResponse {
    logger.log(
      level: .error,
      "✗ \(request.method.rawValue) \(request.url.absoluteString) - \(error.localizedDescription)"
    )

    if let underlyingError = error.underlyingError {
      logger.log(
        level: .error,
        "  Underlying error: \(underlyingError.localizedDescription)"
      )
    }

    // Re-throw the error - this middleware only logs, doesn't handle
    throw error
  }
}

#endif  // canImport(OSLog)
