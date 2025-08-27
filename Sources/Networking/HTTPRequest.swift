import Foundation

/// A structure representing an HTTP request with Swift 6 concurrency compliance.
public struct HTTPRequest: Sendable, Identifiable {
  // MARK: - Properties

  /// Unique identifier for this request
  public let id: UUID

  /// The HTTP method
  public let method: HTTPMethod

  /// The complete URL for the request
  public let url: URL

  /// HTTP headers
  public let headers: [String: String]

  /// Request body data
  public let body: Data?

  /// Request timeout interval
  public let timeout: TimeInterval

  // MARK: - Initialization

  public init(
    method: HTTPMethod,
    url: URL,
    headers: [String: String] = [:],
    body: Data? = nil,
    timeout: TimeInterval = 30.0
  ) {
    self.id = UUID()
    self.method = method
    self.url = url
    self.headers = headers
    self.body = body
    self.timeout = timeout
  }
}
