import Foundation

extension HTTPTrace {
  /// A sanitized HTTP message; bodies are absent unless explicitly enabled.
  public struct Message: Sendable, Codable {
    /// The method for a request, or nil for a response.
    public let method: String?
    /// The URL with user information, query values, and fragments removed.
    public let url: URL?
    /// The response status code, or nil for a request.
    public let statusCode: Int?
    /// Headers after configured redaction.
    public let headers: [String: String]
    /// A bounded prefix of the body, or nil when capture is disabled.
    public let body: Data?
  }
}
