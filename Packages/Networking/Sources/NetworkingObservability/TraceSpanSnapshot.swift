import Foundation
import NetworkingCore

/// An atomic snapshot for exporters; no actor reads are needed during serialization.
public struct TraceSpanSnapshot: Sendable {

  public let name: TraceSpanName

  public let context: TraceContext

  public let startTime: Date

  public let endTime: Date?

  public let status: TraceSpan.SpanStatus

  public let attributes: [TraceAttributeKey: TraceAttributeValue]

  public let events: [TraceSpan.SpanEvent]
}
