import Foundation
import NetworkingCore

/// An atomic snapshot for exporters; no actor reads are needed during serialization.
public struct TraceSpanSnapshot: Sendable {
  /// Operation name.
  public let name: TraceSpanName
  /// Trace and parent identities.
  public let context: TraceContext
  /// Operation start.
  public let startTime: Date
  /// Operation completion, or nil for an active span.
  public let endTime: Date?
  /// Outcome at snapshot time.
  public let status: TraceSpan.SpanStatus
  /// Attributes at snapshot time.
  public let attributes: [TraceAttributeKey: TraceAttributeValue]
  /// Events at snapshot time.
  public let events: [TraceSpan.SpanEvent]
}
