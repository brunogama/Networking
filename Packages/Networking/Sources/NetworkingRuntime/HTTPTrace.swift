import Foundation
import NetworkingCore

/// A transport-attempt identity, distinct from a logical request identity.
public typealias HTTPTraceID = Identifier<HTTPTraceDomain, UUID>

/// A bounded, sanitized snapshot of an HTTP transport attempt.
public struct HTTPTrace: Sendable, Identifiable, Codable {
  /// The transport-attempt identity.
  public let id: HTTPTraceID
  /// The request after diagnostic redaction.
  public let request: Message
  /// The response after diagnostic redaction, when received.
  public internal(set) var response: Message?
  /// The start time of the transport attempt.
  public let startedAt: Date
  /// The end time, including failures and cancellations.
  public internal(set) var endedAt: Date?
  /// The terminal transport error's domain and code, without arbitrary error text.
  public internal(set) var failure: String?
  /// Connection metrics reported by URLSession for this attempt.
  public internal(set) var connections: [Connection] = []
}
