import Foundation
import NetworkingCore

/// An actor-owned trace span whose completed state is immutable.
public actor TraceSpan {
  /// Operation name; callers must avoid credentials and personal data.
  nonisolated public let name: TraceSpanName
  /// Validated trace identity.
  nonisolated public let context: TraceContext
  /// Operation start time.
  nonisolated public let startTime: Date
  /// Completion time, or nil while active.
  public private(set) var endTime: Date?
  /// Terminal status.
  public private(set) var status: SpanStatus = .unset
  /// Attributes captured before completion.
  public private(set) var attributes: [TraceAttributeKey: TraceAttributeValue]
  /// Events captured before completion.
  public private(set) var events: [SpanEvent] = []

  /// Creates an active span; mutable data remains owned by this actor.
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

  /// Indicates whether completion has been recorded.
  public var isEnded: SpanEndedFlag { SpanEndedFlag(endTime != nil) }
  /// Elapsed time once completed.
  public var duration: MeasurementDuration? {
    endTime.map { MeasurementDuration(max(0, $0.timeIntervalSince(startTime))) }
  }

  /// Updates an attribute while active; completed spans do not change.
  public func setAttribute(_ key: TraceAttributeKey, _ value: TraceAttributeValue) {
    guard endTime == nil else { return }
    attributes[key] = value
  }

  /// Appends an event while active.
  public func addEvent(_ event: SpanEvent) {
    guard endTime == nil else { return }
    events.append(event)
  }

  /// Records the first terminal outcome.
  ///
  /// Returns `true` only for the first completion. Later calls, including calls from concurrent
  /// tasks, return `false` and leave the recorded status and time unchanged.
  @discardableResult
  public func end(status: SpanStatus = .ok, endTime: Date = Date()) -> Bool {
    guard self.endTime == nil else { return false }
    self.endTime = max(startTime, endTime)
    self.status = status
    return true
  }

  /// Copies all mutable span data in one actor turn.
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
