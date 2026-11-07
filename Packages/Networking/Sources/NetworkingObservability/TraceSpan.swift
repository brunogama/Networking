import Foundation
import NetworkingCore

/// An actor-owned trace span whose completed state is immutable.
public actor TraceSpan {

  nonisolated public let name: TraceSpanName

  nonisolated public let context: TraceContext

  nonisolated public let startTime: Date

  public private(set) var endTime: Date?

  public private(set) var status: SpanStatus = .unset

  public private(set) var attributes: [TraceAttributeKey: TraceAttributeValue]

  public private(set) var events: [SpanEvent] = []

  public init(
    name: TraceSpanName,
    context: TraceContext,
    startTime: Date = Date(),
    attributes: [TraceAttributeKey: TraceAttributeValue] = [:]
  ) {
    self.name = name
    self.context = context
    self.startTime = startTime
    self.attributes = attributes
  }

  public var isEnded: SpanEndedFlag { SpanEndedFlag(endTime != nil) }

  public var duration: MeasurementDuration? {
    endTime.map { MeasurementDuration(max(0, $0.timeIntervalSince(startTime))) }
  }

  public func setAttribute(_ key: TraceAttributeKey, _ value: TraceAttributeValue) {
    guard endTime == nil else { return }
    attributes[key] = value
  }

  public func addEvent(_ event: SpanEvent) {
    guard endTime == nil else { return }
    events.append(event)
  }

  @discardableResult
  public func end(status: SpanStatus = .ok, endTime: Date = Date()) -> Bool {
    guard self.endTime == nil else { return false }
    self.endTime = max(startTime, endTime)
    self.status = status
    return true
  }

  public func snapshot() -> TraceSpanSnapshot {
    TraceSpanSnapshot(
      name: name,
      context: context,
      startTime: startTime,
      endTime: endTime,
      status: status,
      attributes: attributes,
      events: events
    )
  }
}
