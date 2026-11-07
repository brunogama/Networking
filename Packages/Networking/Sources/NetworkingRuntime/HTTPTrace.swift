import Foundation
import NetworkingCore

/// A transport-attempt identity, distinct from a logical request identity.
public typealias HTTPTraceID = Identifier<HTTPTraceDomain, UUID>

/// A bounded, sanitized snapshot of an HTTP transport attempt.
public struct HTTPTrace: Sendable, Identifiable, Codable {

  public let id: HTTPTraceID

  public let request: Message

  public internal(set) var response: Message?

  public let startedAt: Date

  public internal(set) var endedAt: Date?

  public internal(set) var failure: String?

  public internal(set) var connections: [Connection] = []
}
