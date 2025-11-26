import Foundation

/// A comprehensive error type for HTTP operations with Swift 6 compliance.
public struct HTTPError: Error, Sendable, LocalizedError {
  // MARK: - Error Categories

  public enum Category: Sendable, Hashable {
    case network(NetworkError)
    case http(HTTPStatus)
    case decoding(String)
    case encoding(String)
    case timeout
    case cancelled
    case configuration(String)
    case custom(String, String)  // (type, message)
  }

  /// Categorizes errors by their severity and handling requirements
  public enum ErrorSeverity: Sendable, CaseIterable {
    case low  // Can be ignored or handled gracefully
    case medium  // Should be logged and handled
    case high  // Requires immediate attention
    case critical  // System-threatening, requires emergency handling
  }

  /// Defines how an error can be recovered from
  public enum RecoveryCategory: Sendable, CaseIterable {
    case retryable  // Can be retried immediately
    case retryableWithDelay  // Can be retried after a delay
    case userActionRequired  // Requires user intervention
    case nonRecoverable  // Cannot be recovered from
  }

  public enum NetworkError: Sendable, Hashable {
    case noConnection
    case dnsFailure
    case connectionLost
    case serverUnreachable
    case sslError
  }

  // MARK: - Properties

  /// The error category
  public let category: Category

  /// The original request that caused this error
  public let request: HTTPRequest?

  /// The response received (if any)
  public let response: HTTPResponse?

  /// Underlying system error
  public let underlyingError: (any Error)?

  // MARK: - Initialization

  public init(
    category: Category,
    request: HTTPRequest? = nil,
    response: HTTPResponse? = nil,
    underlyingError: (any Error)? = nil,
    message: String? = nil
  ) {
    self.category = category
    self.request = request
    self.response = response
    self.underlyingError = underlyingError
  }
  // MARK: - LocalizedError

  public var errorDescription: String? {
    switch category {
    case .network(let networkError):
      return "Network error: \(networkError)"

    case .http(let status):
      return "HTTP error: \(status.rawValue)"

    case .decoding(let message):
      return "Decoding error: \(message)"

    case .encoding(let message):
      return "Encoding error: \(message)"

    case .timeout:
      return "Request timed out"

    case .cancelled:
      return "Request was cancelled"

    case .configuration(let message):
      return "Configuration error: \(message)"

    case .custom(let type, let message):
      return "\(type) error: \(message)"
    }
  }

  // MARK: - Convenience Factory Methods

  public static func network(
    _ error: NetworkError,
    request: HTTPRequest? = nil
  ) -> Self {
    Self(category: .network(error), request: request)
  }

  public static func http(
    status: HTTPStatus,
    request: HTTPRequest? = nil,
    response: HTTPResponse? = nil
  ) -> Self {
    Self(category: .http(status), request: request, response: response)
  }

  public static func timeout(request: HTTPRequest) -> Self {
    Self(category: .timeout, request: request)
  }

  public static func cancelled(request: HTTPRequest) -> Self {
    Self(category: .cancelled, request: request)
  }
}

// MARK: - Error Analysis and Recovery

extension HTTPError {
  /// Determines the severity of this error
  public var severity: ErrorSeverity {
    switch category {
    case .network(let networkError):
      switch networkError {
      case .noConnection, .connectionLost:
        return .high

      case .dnsFailure, .serverUnreachable:
        return .medium

      case .sslError:
        return .critical
      }

    case .http(let status):
      switch status.rawValue {
      case 400...499:
        return status.rawValue == 401 || status.rawValue == 403 ? .high : .medium

      case 500...599:
        return .high

      default:
        return .low
      }

    case .timeout:
      return .medium

    case .cancelled:
      return .low

    case .decoding, .encoding:
      return .medium

    case .configuration:
      return .critical

    case .custom(let type, _):
      // Security errors are high severity, others are medium
      return type.lowercased() == "security" ? .high : .medium
    }
  }

  /// Categorizes this error for recovery purposes
  public var recoveryCategory: RecoveryCategory {
    switch category {
    case .network(let networkError):
      switch networkError {
      case .noConnection, .connectionLost:
        return .retryableWithDelay

      case .dnsFailure:
        return .userActionRequired

      case .serverUnreachable:
        return .retryableWithDelay

      case .sslError:
        return .userActionRequired
      }

    case .http(let status):
      switch status.rawValue {
      case 401, 403:
        return .userActionRequired  // Authentication/Authorization required
      case 404:
        return .nonRecoverable  // Resource not found
      case 408, 429:
        return .retryableWithDelay  // Timeout or rate limit
      case 500...503:
        return .retryableWithDelay  // Server errors, might recover
      case 504, 505...599:
        return .nonRecoverable  // Gateway/version errors
      default:
        return .retryable
      }

    case .timeout:
      return .retryableWithDelay

    case .cancelled:
      return .nonRecoverable

    case .decoding, .encoding:
      return .nonRecoverable  // Data format issues
    case .configuration:
      return .userActionRequired  // App configuration issues

    case .custom(let type, _):
      // Security errors require user action, others may be retryable
      return type.lowercased() == "security" ? .userActionRequired : .retryableWithDelay
    }
  }

  /// Provides a user-friendly description with recovery suggestions
  public var userFriendlyDescription: String {
    let baseDescription = errorDescription ?? "An error occurred"
    let recoverySuggestion = recoverySuggestions.first ?? "Please try again later."
    return "\(baseDescription). \(recoverySuggestion)"
  }

  /// Provides actionable recovery suggestions for this error
  public var recoverySuggestions: [String] {
    switch category {
    case .network(let networkError):
      switch networkError {
      case .noConnection:
        return [
          "Check your internet connection and try again.",
          "Make sure you're connected to WiFi or cellular data.",
          "Try switching between WiFi and cellular data.",
        ]

      case .dnsFailure:
        return [
          "Check that the server address is correct.",
          "Try again in a moment as this might be a temporary issue.",
          "Contact your network administrator if this persists.",
        ]

      case .connectionLost:
        return [
          "Your connection was interrupted. Please try again.",
          "Check your network stability.",
        ]

      case .serverUnreachable:
        return [
          "The server is temporarily unavailable. Please try again later.",
          "Check if the service is down for maintenance.",
        ]

      case .sslError:
        return [
          "There's a security issue with the connection.",
          "Check your device's date and time settings.",
          "Contact support if this continues.",
        ]
      }

    case .http(let status):
      switch status.rawValue {
      case 401:
        return [
          "You need to log in again.",
          "Check your credentials and try signing in.",
        ]

      case 403:
        return [
          "You don't have permission to access this resource.",
          "Contact your administrator for access.",
        ]

      case 404:
        return [
          "The requested resource could not be found.",
          "Check the URL and try again.",
        ]

      case 408:
        return [
          "The request took too long. Please try again.",
          "Check your connection speed.",
        ]

      case 429:
        return [
          "Too many requests. Please wait a moment and try again.",
          "Reduce the frequency of your requests.",
        ]

      case 500...503:
        return [
          "The server is experiencing issues. Please try again later.",
          "Contact support if this problem continues.",
        ]

      default:
        return ["Please try again or contact support if the problem continues."]
      }

    case .timeout:
      return [
        "The request took too long to complete. Please try again.",
        "Check your connection speed.",
        "Try again with a shorter request or better connection.",
      ]

    case .cancelled:
      return ["The request was cancelled. You can try again if needed."]

    case .decoding:
      return [
        "There was an issue processing the server response.",
        "Please try again or contact support.",
      ]

    case .encoding:
      return [
        "There was an issue preparing your request.",
        "Please check your input and try again.",
      ]

    case .configuration:
      return [
        "There's a configuration issue with the app.",
        "Please contact support or reinstall the app.",
      ]

    case .custom(let type, let message):
      if type.lowercased() == "security" {
        return [
          "Security issue detected: \(message)",
          "Please check your request and ensure it follows security guidelines.",
          "Contact support if this continues.",
        ]
      } else {
        return [
          "\(type) issue: \(message)",
          "Please try again or contact support if the problem continues.",
        ]
      }
    }
  }

  /// Indicates if this error suggests a client-side issue
  public var isClientError: Bool {
    switch category {
    case .http(let status):
      return 400...499 ~= status.rawValue

    case .encoding, .configuration:
      return true

    default:
      return false
    }
  }

  /// Indicates if this error suggests a server-side issue
  public var isServerError: Bool {
    switch category {
    case .http(let status):
      return 500...599 ~= status.rawValue

    case .network:
      return true

    default:
      return false
    }
  }

  /// Indicates if this error is likely temporary and might resolve on retry
  public var isTransientError: Bool {
    recoveryCategory == .retryable || recoveryCategory == .retryableWithDelay
  }

  /// Provides debug information for developers
  public var debugDescription: String {
    var parts = [
      "HTTPError:",
      "Category: \(category)",
      "Severity: \(severity)",
      "Recovery: \(recoveryCategory)",
    ]

    if let request = request {
      parts.append("Request: \(request.method.rawValue) \(request.url)")
    }

    if let response = response {
      parts.append("Response: \(response.status.rawValue)")
    }

    if let underlyingError = underlyingError {
      parts.append("Underlying: \(underlyingError.localizedDescription)")
    }

    return parts.joined(separator: ", ")
  }
}

// MARK: - Enhanced Recovery Context (PRP Specification)

extension HTTPError {
  /// Single recovery suggestion (first from suggestions list)
  public var recoverySuggestion: String? {
    recoverySuggestions.first
  }

  /// Indicates if this error can be retried (alias for isTransientError)
  public var isRetryable: Bool {
    isTransientError
  }

  /// Comprehensive actionable error information with recovery strategies
  public var actionableInfo: ActionableErrorInfo {
    ActionableErrorInfo.analyze(self)
  }

  /// Creates actionable info with specific context
  public func actionableInfo(
    with context: ActionableErrorInfo.ErrorContext
  ) -> ActionableErrorInfo {
    ActionableErrorInfo.analyze(self, context: context)
  }

  /// Suggested delay before retry (for retryable errors)
  public var retryAfter: TimeInterval? {
    switch recoveryCategory {
    case .retryable:
      return NetworkingConfiguration.RetryDelays.immediate

    case .retryableWithDelay:
      switch category {
      case .network(.connectionLost):
        return NetworkingConfiguration.RetryDelays.connectionLost

      case .network(.serverUnreachable):
        return NetworkingConfiguration.RetryDelays.serverUnreachable

      case .http(let status) where status.rawValue == 429:
        return NetworkingConfiguration.RetryDelays.rateLimiting

      case .http(let status) where (500...503).contains(status.rawValue):
        return NetworkingConfiguration.RetryDelays.serverError

      case .timeout:
        return NetworkingConfiguration.RetryDelays.timeout

      default:
        return NetworkingConfiguration.RetryDelays.default
      }

    case .userActionRequired, .nonRecoverable:
      return nil
    }
  }
}
