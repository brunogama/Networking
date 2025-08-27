import Foundation
import OSLog

/// Middleware that logs HTTP requests and responses using OSLog.
public struct LoggingMiddleware: HTTPRequestMiddleware, HTTPResponseMiddleware, HTTPErrorMiddleware
{
  // MARK: - Configuration

  public struct Configuration: Sendable {
    public let subsystem: String
    public let category: String
    public let logLevel: OSLogType
    public let logHeaders: Bool
    public let logBody: Bool
    public let maxBodyLength: Int

    public init(
      subsystem: String = "Networking",
      category: String = "HTTPClient",
      logLevel: OSLogType = .debug,
      logHeaders: Bool = true,
      logBody: Bool = false,
      maxBodyLength: Int = 1024
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
      subsystem: configuration.subsystem,
      category: configuration.category
    )
  }
  // MARK: - HTTPRequestMiddleware

  public func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
    logger.log(
      level: configuration.logLevel,
      "→ \(request.method.rawValue) \(request.url.absoluteString)"
    )

    if configuration.logHeaders && !request.headers.isEmpty {
      logger.log(
        level: configuration.logLevel,
        "  Headers: \(request.headers.description)"
      )
    }

    if configuration.logBody,
      let body = request.body,
      let bodyString = String(data: body, encoding: .utf8)
    {
      let truncatedBody = String(bodyString.prefix(configuration.maxBodyLength))
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

    if configuration.logHeaders && !response.headers.isEmpty {
      logger.log(
        level: configuration.logLevel,
        "  Headers: \(response.headers.description)"
      )
    }

    if configuration.logBody,
      let body = response.body,
      let bodyString = String(data: body, encoding: .utf8)
    {
      let truncatedBody = String(bodyString.prefix(configuration.maxBodyLength))
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
