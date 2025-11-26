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
public struct LoggingInterceptor: RequestInterceptor, ResponseInterceptor, Sendable {
  /// Log level determines what information is logged
  public enum LogLevel: Int, Sendable, Comparable {
    /// No logging
    case none = 0
    /// Log only errors
    case error = 1
    /// Log errors and basic request/response info
    case basic = 2
    /// Log headers and response size
    case headers = 3
    /// Log everything including body previews
    case verbose = 4

    public static func < (lhs: Self, rhs: Self) -> Bool {
      lhs.rawValue < rhs.rawValue
    }
  }

  public let level: LogLevel
  private let logger: @Sendable (String) -> Void

  /// Creates a logging interceptor with specified log level.
  ///
  /// - Parameters:
  ///   - level: The logging verbosity level
  ///   - logger: Optional custom logging function. Defaults to print().
  public init(
    level: LogLevel = .basic,
    logger: @escaping @Sendable (String) -> Void = { print($0) }
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
    guard level > .none else { return .proceed }

    let statusCode = response.status.rawValue
    let isError = statusCode >= 400

    // Only log errors at .error level, everything at .basic and above
    guard level > .error || isError else { return .proceed }

    var logMessage = "[RESPONSE] \(context.method.rawValue) \(context.path) - \(statusCode)"
    if isError {
      logMessage += " ❌"
    }

    if level >= .headers {
      logMessage += "\nHeaders: \(redactSensitiveHeaders(response.headers))"
    }

    if level >= .verbose, let bodySize = response.body?.count {
      logMessage += "\nBody: \(bodySize) bytes"
    }

    logger(logMessage)

    return .proceed
  }

  // MARK: - Private Helpers

  /// Redacts sensitive headers like Authorization and API keys
  private func redactSensitiveHeaders(_ headers: [String: String]) -> [String: String] {
    let sensitiveKeys = ["authorization", "api-key", "x-api-key", "cookie", "set-cookie"]

    var redacted: [String: String] = [:]
    for (key, value) in headers {
      if sensitiveKeys.contains(key.lowercased()) {
        redacted[key] = "[REDACTED]"
      } else {
        redacted[key] = value
      }
    }
    return redacted
  }
}

// MARK: - Convenience Constructors

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
