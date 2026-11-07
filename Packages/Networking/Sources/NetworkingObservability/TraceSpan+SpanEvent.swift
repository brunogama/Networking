import Foundation
import NetworkingCore

extension TraceSpan {
  /// A timestamped, caller-sanitized event.
  public struct SpanEvent: Sendable {
    /// Event name.
    public let name: SpanEventName
    /// Event time.
    public let timestamp: Date
    /// Event attributes.
    public let attributes: [TraceAttributeKey: TraceAttributeValue]

    /// Creates an event for an active span.
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
