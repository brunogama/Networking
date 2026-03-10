import NetworkingRuntime
import Foundation

/// Interceptor that logs HTTP requests and responses for debugging and monitoring.
///
/// Implements both `RequestInterceptor` and `ResponseInterceptor` to log the complete
/// request/response cycle. Supports configurable log levels and privacy-aware logging.
///
/// ## Usage
///
/// ```swift
/// let logger = LoggingInterceptor(level: .verbose)
///
/// @API(baseURL: "https://api.example.com")
/// @Interceptors([logger])
/// protocol UserAPI {
///   @GET("/users/{id}")
///   func getUser(id: String) async throws -> User
/// }
/// ```
///
/// ## Log Output Example
///
/// ```
/// [REQUEST] GET /users/123
/// Headers: ["Content-Type": "application/json"]
///
/// [RESPONSE] GET /users/123 - 200 OK (142ms)
/// Headers: ["Content-Type": "application/json"]
/// Body: 1234 bytes
/// ```
@available(
  *,
  deprecated,
  message: """
    LoggingInterceptor is a compatibility API.
    Prefer request, response, or error middleware for new runtime behavior.
    """
)
public struct LoggingInterceptor: RequestInterceptor, ResponseInterceptor, Sendable {
  /// Log level determines what information is logged
  public enum LogLevel: Sendable, Comparable {
    /// No logging
    case none
    /// Log only errors
    case error
    /// Log errors and basic request/response info
    case basic
    /// Log headers and response size
    case headers
    /// Log everything including body previews
    case verbose

    private var rank: LoggingLevelRank {
      switch self {
      case .none: return 0
      case .error: return 1
      case .basic: return 2
      case .headers: return 3
      case .verbose: return 4
      }
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
      lhs.rank < rhs.rank
    }
  }

  public let level: LogLevel
  private let logger: @Sendable (String) -> Void

  /// Creates a logging interceptor with specified log level.
  ///
  /// - Parameters:
  ///   - level: The logging verbosity level
  ///   - logger: Optional custom logging function. Defaults to `NSLog`.
  public init(
    level: LogLevel = .basic,
    logger: @escaping @Sendable (String) -> Void = { message in
      NSLog("%@", message)
    }
  ) {
    self.level = level
    self.logger = logger
  }

  // MARK: - RequestInterceptor

  public func intercept(
    request: inout HTTPRequest,
    context: InterceptorContext
  ) async throws -> InterceptorResult {
    guard level >= .basic else { return .proceed }

    var logMessage = "[REQUEST] \(context.method.rawValue) \(context.path)"

    if level >= .headers {
      logMessage += "\nHeaders: \(redactSensitiveHeaders(request.headers))"
    }

    if level >= .verbose, let bodySize = request.body?.count {
      logMessage += "\nBody: \(bodySize) bytes"
    }

    logger(logMessage)

    return .proceed
  }

  // MARK: - ResponseInterceptor

  public func intercept(
    response: HTTPResponse,
    context: InterceptorContext
  ) async throws -> InterceptorResult {
    guard let logMessage = responseLogMessage(for: response, context: context) else {
      return .proceed
    }

    logger(logMessage)

    return .proceed
  }

  private func responseLogMessage(
    for response: HTTPResponse,
    context: InterceptorContext
  ) -> String? {
    guard level > .none else { return nil }

    let statusCode = response.status.rawValue
    guard level > .error || statusCode >= 400 else { return nil }

    return appendResponseDetails(
      to: baseResponseLogMessage(statusCode: statusCode, context: context),
      response: response
    )
  }

  private func baseResponseLogMessage(
    statusCode: HTTPStatusCode,
    context: InterceptorContext
  ) -> String {
    var logMessage = "[RESPONSE] \(context.method.rawValue) \(context.path) - \(statusCode)"
    if statusCode >= 400 {
      logMessage += " ❌"
    }
    return logMessage
  }

  private func appendResponseDetails(to baseMessage: String, response: HTTPResponse) -> String {
    var logMessage = baseMessage

    if level >= .headers {
      logMessage += "\nHeaders: \(redactSensitiveHeaders(response.headers))"
    }

    if level >= .verbose, let bodySize = response.body?.count {
      logMessage += "\nBody: \(bodySize) bytes"
    }

    return logMessage
  }

  // MARK: - Private Helpers

  /// Redacts sensitive headers like Authorization and API keys
  private func redactSensitiveHeaders(_ headers: HTTPHeaders) -> [String: String] {
    let sensitiveKeys = ["authorization", "api-key", "x-api-key", "cookie", "set-cookie"]

    var redacted: [String: String] = [:]
    for (key, value) in headers {
      if sensitiveKeys.contains(key.rawValue.lowercased()) {
        redacted[key.rawValue] = "[REDACTED]"
      } else {
        redacted[key.rawValue] = value.rawValue
      }
    }
    return redacted
  }
}

// MARK: - Convenience Constructors

@available(
  *,
  deprecated,
  message: """
    LoggingInterceptor is a compatibility API.
    Prefer request, response, or error middleware for new runtime behavior.
    """
)
extension LoggingInterceptor {
  /// Creates a logging interceptor that only logs errors
  public static var errorsOnly: Self {
    Self(level: .error)
  }

  /// Creates a logging interceptor with basic request/response logging
  public static var basic: Self {
    Self(level: .basic)
  }

  /// Creates a logging interceptor with header logging
  public static var withHeaders: Self {
    Self(level: .headers)
  }

  /// Creates a logging interceptor with full verbose logging
  public static var verbose: Self {
    Self(level: .verbose)
  }
}
