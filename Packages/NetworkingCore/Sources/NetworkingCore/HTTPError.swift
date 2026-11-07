import Foundation

/// A comprehensive error type for HTTP operations with Swift 6 compliance.
public struct HTTPError: Error, Sendable, LocalizedError, CustomDebugStringConvertible {

  // MARK: - Properties

  public let category: Category

  public let request: HTTPRequest?

  public let response: HTTPResponse?

  public let underlyingError: (any Error)?

  public let message: HTTPErrorDetail?

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
    self.message = message
  }
  // MARK: - LocalizedError

  public var debugDescription: String { errorDescription ?? "HTTPError" }

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
