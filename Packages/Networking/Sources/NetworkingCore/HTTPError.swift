import Foundation

/// A comprehensive error type for HTTP operations with Swift 6 compliance.
public struct HTTPError: Error, Sendable, LocalizedError, CustomDebugStringConvertible {
  // MARK: - Error Categories

  public enum Category: Sendable, Hashable {
    case network(NetworkError)
    case http(HTTPStatus)
    case decoding(HTTPErrorDetail)
    case encoding(HTTPErrorDetail)
    case timeout
    case cancelled
    case configuration(HTTPErrorDetail)
    case custom(HTTPErrorTypeName, HTTPErrorDetail)  // (type, message)
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
    message: HTTPErrorDetail? = nil
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
