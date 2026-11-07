import Foundation

/// A comprehensive error type for HTTP operations with Swift 6 compliance.
public struct HTTPError: Error, Sendable, LocalizedError, CustomDebugStringConvertible {

  // MARK: - Properties

  /// The error category.
  public let category: Category

  /// The original request that caused this error.
  public let request: HTTPRequest?

  /// The response received, if any.
  public let response: HTTPResponse?

  /// The underlying system error.
  public let underlyingError: (any Error)?

  /// Additional context supplied by the caller.
  public let message: HTTPErrorDetail?

  // MARK: - Initialization

  /// Creates a failure with optional request, response, and underlying error context.
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
    self.message = message
  }
  // MARK: - LocalizedError

  /// A concise error description without dumping its request or response.
  public var debugDescription: String { errorDescription ?? "HTTPError" }

  /// Describes the category or caller-supplied context.
  public var errorDescription: String? {
    if let message {
      return message.rawValue
    }
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

  /// Creates a transport failure associated with an optional request.
  public static func network(
    _ error: NetworkError,
    request: HTTPRequest? = nil
  ) -> Self {
    Self(category: .network(error), request: request)
  }

  /// Creates a failure for an HTTP response status.
  public static func http(
    status: HTTPStatus,
    request: HTTPRequest? = nil,
    response: HTTPResponse? = nil
  ) -> Self {
    Self(category: .http(status), request: request, response: response)
  }

  /// Creates a timeout failure for a request.
  public static func timeout(request: HTTPRequest) -> Self {
    Self(category: .timeout, request: request)
  }

  /// Creates a cancellation failure for a request.
  public static func cancelled(request: HTTPRequest) -> Self {
    Self(category: .cancelled, request: request)
  }
}
