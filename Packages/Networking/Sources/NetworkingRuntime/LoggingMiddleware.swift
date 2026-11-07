import Foundation
import NetworkingCore

#if canImport(OSLog)
import OSLog

/// Middleware that logs HTTP requests and responses using OSLog.
public struct LoggingMiddleware: HTTPRequestMiddleware, HTTPResponseMiddleware, HTTPErrorMiddleware
{

  // MARK: - Properties

  private let configuration: Configuration
  private let logger: Logger

  // MARK: - Initialization

  /// Creates logging middleware with explicit content capture settings.
  public init(configuration: Configuration = Configuration()) {
    self.configuration = configuration
    self.logger = Logger(
      subsystem: configuration.subsystem.rawValue,
      category: configuration.category.rawValue
    )
  }
  // MARK: - HTTPRequestMiddleware

  /// Logs the outgoing request and returns it unchanged.
  public func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
    logger.log(
      level: configuration.logLevel,
      "→ \(request.method.rawValue) \(request.url.rawValue.absoluteString)"
    )

    if configuration.logHeaders.rawValue && !request.headers.isEmpty.rawValue {
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

  /// Logs the completed response and returns it unchanged.
  public func processResponse(
    _ response: HTTPResponse,
    for request: HTTPRequest
  ) async throws -> HTTPResponse {
    logger.log(
      level: configuration.logLevel,
      "← \(response.status.rawValue) \(request.method.rawValue) \(request.url.rawValue.absoluteString)"
    )

    if configuration.logHeaders.rawValue && !response.headers.isEmpty.rawValue {
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

  /// Logs and rethrows the original HTTP error.
  public func handleError(
    _ error: HTTPError,
    for request: HTTPRequest
  ) async throws -> HTTPResponse {
    logger.log(
      level: .error,
      "✗ \(request.method.rawValue) \(request.url.rawValue.absoluteString) - \(error.localizedDescription)"
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
