import Foundation
import NetworkingCore

extension TraceSpan {
  /// A timestamped, caller-sanitized event.
  public struct SpanEvent: Sendable {

    public let name: SpanEventName

    public let timestamp: Date

    public let attributes: [TraceAttributeKey: TraceAttributeValue]

    public init(
      name: SpanEventName,
      timestamp: Date = Date(),
      attributes: [TraceAttributeKey: TraceAttributeValue] = [:]
    ) {
      self.name = name
      self.timestamp = timestamp
      self.attributes = attributes
    }
  }
}
