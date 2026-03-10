import NetworkingRuntime
import Foundation

// MARK: - Trace Context (W3C)

/// A W3C Trace Context for distributed tracing across service boundaries.
///
/// Implements the [W3C Trace Context](https://www.w3.org/TR/trace-context/) specification
/// for propagating trace information through HTTP headers.
///
/// ## Usage
///
/// ```swift
/// let context = TraceContext()
/// let headerValue = context.traceparent
/// // "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
/// ```
public struct TraceContext: Sendable, Equatable {
  /// The version of the trace context specification (always "00").
  public let version = TraceVersion(rawValue: "00")

  /// A 16-byte (32-hex-character) globally unique trace identifier.
  public let traceId: TraceIdentifier

  /// An 8-byte (16-hex-character) span identifier.
  public let spanId: SpanIdentifier

  /// The parent span identifier, if this span has a parent.
  public let parentSpanId: SpanIdentifier?

  /// Trace flags (1 byte). Bit 0 = sampled.
  public let traceFlags: TraceFlags

  /// Whether this trace is sampled.
  public var isSampled: TraceSampledFlag {
    TraceSampledFlag((traceFlags.rawValue & 0x01) != 0)
  }

  /// Additional vendor-specific trace state.
  public let traceState: [TraceStateKey: TraceStateValue]

  /// Creates a new trace context with random identifiers.
  ///
  /// - Parameters:
  ///   - parentSpanId: Optional parent span ID for creating child spans
  ///   - traceId: Optional trace ID (generated if nil)
  ///   - traceFlags: Trace flags (default: 0x01 = sampled)
  ///   - traceState: Additional trace state (default: empty)
  public init(
    parentSpanId: SpanIdentifier? = nil,
    traceId: TraceIdentifier? = nil,
    traceFlags: TraceFlags = TraceFlags(rawValue: 0x01),
    traceState: [TraceStateKey: TraceStateValue] = [:]
  ) {
    self.traceId = traceId ?? Self.generateTraceId()
    self.spanId = Self.generateSpanId()
    self.parentSpanId = parentSpanId
    self.traceFlags = traceFlags
    self.traceState = traceState
  }

  /// The `traceparent` header value per the W3C specification.
  ///
  /// Format: `{version}-{trace-id}-{span-id}-{trace-flags}`
  ///
  /// Example: `"00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"`
  public var traceparent: HTTPHeaderValue {
    let flags = String(format: "%02x", traceFlags.rawValue)
    return HTTPHeaderValue("\(version)-\(traceId)-\(spanId)-\(flags)")
  }

  /// The `tracestate` header value, if any state entries exist.
  ///
  /// Format: `key1=value1,key2=value2`
  public var tracestateHeader: HTTPHeaderValue? {
    guard !traceState.isEmpty else { return nil }
    return HTTPHeaderValue(
      traceState.map { "\($0.key)=\($0.value)" }.joined(separator: ",")
    )
  }

  /// Creates a child context that inherits this context's trace ID.
  ///
  /// - Returns: A new trace context with a new span ID and this span as parent
  public func createChild() -> Self {
    Self(
      parentSpanId: spanId,
      traceId: traceId,
      traceFlags: traceFlags,
      traceState: traceState
    )
  }

  /// Parses a `traceparent` header value.
  ///
  /// - Parameter header: The traceparent header string
  /// - Returns: A trace context, or nil if parsing fails
  public static func parse(traceparent header: HTTPHeaderValue) -> Self? {
    let parts = header.rawValue.split(separator: "-")
    guard parts.count == 4 else { return nil }
    guard parts[0] == "00" else { return nil }

    let traceId = TraceIdentifier(String(parts[1]))
    let spanId = SpanIdentifier(String(parts[2]))
    guard traceId.rawValue.count == 32, spanId.rawValue.count == 16 else { return nil }

    guard let flags = UInt8(parts[3], radix: 16) else { return nil }

    return Self(
      parentSpanId: spanId,
      traceId: traceId,
      traceFlags: TraceFlags(Int(flags))
    )
  }

  // MARK: - ID Generation

  /// Generates a 32-hex-character trace ID.
  public static func generateTraceId() -> TraceIdentifier {
    var bytes = [UInt8](repeating: 0, count: 16)
    for i in 0..<16 { bytes[i] = UInt8.random(in: 0...255) }
    return TraceIdentifier(bytes.map { String(format: "%02x", $0) }.joined())
  }

  /// Generates a 16-hex-character span ID.
  public static func generateSpanId() -> SpanIdentifier {
    var bytes = [UInt8](repeating: 0, count: 8)
    for i in 0..<8 { bytes[i] = UInt8.random(in: 0...255) }
    return SpanIdentifier(bytes.map { String(format: "%02x", $0) }.joined())
  }
}

// MARK: - Trace Span

/// A span representing a unit of work in a distributed trace.
///
/// Spans track the start and end time of an operation, along with
/// any attributes, events, and status information.
///
/// Implemented as an actor to ensure thread-safe access to mutable state
/// (endTime, status, attributes, events) without manual locking.
///
/// ```swift
/// let span = TraceSpan(name: "GET /users", context: TraceContext())
/// // ... perform work ...
/// await span.end(status: .ok)
/// ```
public actor TraceSpan {
  /// The span name (typically the operation being performed).
  nonisolated public let name: TraceSpanName

  /// The trace context associated with this span.
  nonisolated public let context: TraceContext

  /// The start time of this span.
  nonisolated public let startTime: Date

  /// The end time of this span (nil if still active).
  public private(set) var endTime: Date?

  /// The span status.
  public private(set) var status: SpanStatus = .unset

  /// Custom attributes attached to this span.
  public private(set) var attributes: [TraceAttributeKey: TraceAttributeValue] = [:]

  /// Events that occurred during the span.
  public private(set) var events: [SpanEvent] = []

  /// Span status codes.
  public enum SpanStatus: Sendable {
    case unset
    case ok
    case error(SpanStatusMessage)
  }

  /// An event that occurred during a span.
  public struct SpanEvent: Sendable {
    /// The event name.
    public let name: SpanEventName

    /// When the event occurred.
    public let timestamp: Date

    /// Event attributes.
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

  /// Whether this span has ended.
  public var isEnded: SpanEndedFlag {
    SpanEndedFlag(endTime != nil)
  }

  /// The duration of this span (nil if still active).
  public var duration: MeasurementDuration? {
    guard let end = endTime else { return nil }
    return MeasurementDuration(end.timeIntervalSince(startTime))
  }

  /// Creates a new span.
  ///
  /// - Parameters:
  ///   - name: The span name
  ///   - context: The trace context
  ///   - startTime: The start time (default: now)
  public init(name: TraceSpanName, context: TraceContext, startTime: Date = Date()) {
    self.name = name
    self.context = context
    self.startTime = startTime
  }

  /// Sets an attribute on this span.
  ///
  /// - Parameters:
  ///   - key: The attribute key
  ///   - value: The attribute value
  public func setAttribute(_ key: TraceAttributeKey, _ value: TraceAttributeValue) {
    attributes[key] = value
  }

  /// Adds an event to this span.
  ///
  /// - Parameter event: The event to add
  public func addEvent(_ event: SpanEvent) {
    events.append(event)
  }

  /// Ends this span with the specified status.
  ///
  /// - Parameters:
  ///   - status: The span status (default: `.ok`)
  ///   - endTime: The end time (default: now)
  public func end(status: SpanStatus = .ok, endTime: Date = Date()) {
    guard self.endTime == nil else { return }
    self.endTime = endTime
    self.status = status
  }
}
