import Foundation

extension HTTPTrace {
  /// Measurements of one connection transaction, including redirects and connection reuse.
  public struct Connection: Sendable, Codable {

    public let protocolName: String?

    public let reused: Bool

    public let dns: TimeInterval?

    public let connect: TimeInterval?

    public let tls: TimeInterval?

    public let timeToFirstByte: TimeInterval?
  }
}
