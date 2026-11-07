import Foundation

extension HTTPTrace {
  /// Measurements of one connection transaction, including redirects and connection reuse.
  public struct Connection: Sendable, Codable {
    /// The negotiated network protocol, such as h2 or http/1.1.
    public let protocolName: String?
    /// Whether URLSession reused an existing connection.
    public let reused: Bool
    /// DNS lookup time in seconds, when measured.
    public let dns: TimeInterval?
    /// Connection establishment time in seconds, when measured.
    public let connect: TimeInterval?
    /// TLS negotiation time in seconds, when measured.
    public let tls: TimeInterval?
    /// Time from starting the request to receiving its first response byte.
    public let timeToFirstByte: TimeInterval?
  }
}
