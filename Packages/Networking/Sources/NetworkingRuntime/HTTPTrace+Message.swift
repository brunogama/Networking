import Foundation

extension HTTPTrace {
  /// A sanitized HTTP message; bodies are absent unless explicitly enabled.
  public struct Message: Sendable, Codable {

    public let method: String?

    public let url: URL?

    public let statusCode: Int?

    public let headers: [String: String]

    public let body: Data?
  }
}
