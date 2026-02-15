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
/// print(context.traceparent)
/// // "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
/// ```
public struct TraceContext: Sendable, Equatable {
  /// The version of the trace context specification (always "00").
  public let version: String = "00"

  /// A 16-byte (32-hex-character) globally unique trace identifier.
  public let traceId: String

  /// An 8-byte (16-hex-character) span identifier.
  public let spanId: String

  /// The parent span identifier, if this span has a parent.
  public let parentSpanId: String?

  /// Trace flags (1 byte). Bit 0 = sampled.
  public let traceFlags: UInt8

  /// Whether this trace is sampled.
  public var isSampled: Bool {
    traceFlags & 0x01 != 0
  }

  /// Additional vendor-specific trace state.
  public let traceState: [String: String]

  /// Creates a new trace context with random identifiers.
  ///
  /// - Parameters:
  ///   - parentSpanId: Optional parent span ID for creating child spans
  ///   - traceId: Optional trace ID (generated if nil)
  ///   - traceFlags: Trace flags (default: 0x01 = sampled)
  ///   - traceState: Additional trace state (default: empty)
  public init(
    parentSpanId: String? = nil,
    traceId: String? = nil,
    traceFlags: UInt8 = 0x01,
    traceState: [String: String] = [:]
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
  public var traceparent: String {
    let flags = String(format: "%02x", traceFlags)
    return "\(version)-\(traceId)-\(spanId)-\(flags)"
  }

  /// The `tracestate` header value, if any state entries exist.
  ///
  /// Format: `key1=value1,key2=value2`
  public var tracestateHeader: String? {
    guard !traceState.isEmpty else { return nil }
    return traceState.map { "\($0.key)=\($0.value)" }.joined(separator: ",")
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
  public static func parse(traceparent header: String) -> Self? {
    let parts = header.split(separator: "-")
    guard parts.count == 4 else { return nil }
    guard parts[0] == "00" else { return nil }

    let traceId = String(parts[1])
    let spanId = String(parts[2])
    guard traceId.count == 32, spanId.count == 16 else { return nil }

    guard let flags = UInt8(parts[3], radix: 16) else { return nil }

    return Self(
      parentSpanId: spanId,
      traceId: traceId,
      traceFlags: flags
    )
  }

  // MARK: - ID Generation

  /// Generates a 32-hex-character trace ID.
  public static func generateTraceId() -> String {
    var bytes = [UInt8](repeating: 0, count: 16)
    for i in 0..<16 { bytes[i] = UInt8.random(in: 0...255) }
    return bytes.map { String(format: "%02x", $0) }.joined()
  }

  /// Generates a 16-hex-character span ID.
  public static func generateSpanId() -> String {
    var bytes = [UInt8](repeating: 0, count: 8)
    for i in 0..<8 { bytes[i] = UInt8.random(in: 0...255) }
    return bytes.map { String(format: "%02x", $0) }.joined()
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
  nonisolated public let name: String

  /// The trace context associated with this span.
  nonisolated public let context: TraceContext

  /// The start time of this span.
  nonisolated public let startTime: Date

  /// The end time of this span (nil if still active).
  public private(set) var endTime: Date?

  /// The span status.
  public private(set) var status: SpanStatus = .unset

  /// Custom attributes attached to this span.
  public private(set) var attributes: [String: String] = [:]

  /// Events that occurred during the span.
  public private(set) var events: [SpanEvent] = []

  /// Span status codes.
  public enum SpanStatus: Sendable {
    case unset
    case ok
    case error(String)
  }

  /// An event that occurred during a span.
  public struct SpanEvent: Sendable {
    /// The event name.
    public let name: String

    /// When the event occurred.
    public let timestamp: Date

    /// Event attributes.
    public let attributes: [String: String]

    public init(name: String, timestamp: Date = Date(), attributes: [String: String] = [:]) {
      self.name = name
      self.timestamp = timestamp
      self.attributes = attributes
    }
  }

  /// Whether this span has ended.
  public var isEnded: Bool {
    endTime != nil
  }

  /// The duration of this span (nil if still active).
  public var duration: TimeInterval? {
    guard let end = endTime else { return nil }
    return end.timeIntervalSince(startTime)
  }

  /// Creates a new span.
  ///
  /// - Parameters:
  ///   - name: The span name
  ///   - context: The trace context
  ///   - startTime: The start time (default: now)
  public init(name: String, context: TraceContext, startTime: Date = Date()) {
    self.name = name
    self.context = context
    self.startTime = startTime
  }

  /// Sets an attribute on this span.
  ///
  /// - Parameters:
  ///   - key: The attribute key
  ///   - value: The attribute value
  public func setAttribute(_ key: String, _ value: String) {
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

// MARK: - Trace Exporter Protocol

/// Protocol for exporting trace data to external systems.
///
/// Implement this protocol to send span data to backends like Jaeger,
/// Zipkin, or OpenTelemetry collectors.
public protocol TraceExporter: Sendable {
  /// Exports a completed span.
  ///
  /// - Parameter span: The span to export
  func export(_ span: TraceSpan) async throws

  /// Flushes any buffered spans.
  func flush() async throws
}

// MARK: - Console Trace Exporter

/// A trace exporter that prints spans to the console (useful for debugging).
public struct ConsoleTraceExporter: TraceExporter {
  public init() {}

  public func export(_ span: TraceSpan) async throws {
    let durationValue = await span.duration
    let duration = durationValue.map { String(format: "%.3fms", $0 * 1000) } ?? "active"
    print(
      "[TRACE] \(span.name) | trace=\(span.context.traceId.prefix(8))... | span=\(span.context.spanId.prefix(8))... | \(duration)"
    )
  }

  public func flush() async throws {}
}

// MARK: - Tracing Middleware

/// Middleware that injects W3C Trace Context headers into outgoing requests
/// and records spans for each request lifecycle.
///
/// ## Usage
///
/// ```swift
/// let tracingMiddleware = TracingMiddleware()
///
/// let client = try NetworkClient(components: [
///     BaseURL("https://api.example.com"),
///     AddMiddleware(tracingMiddleware)
/// ])
/// ```
///
/// This will automatically add `traceparent` and `tracestate` headers to all
/// outgoing requests and record timing information for each request.
public final class TracingMiddleware: HTTPRequestMiddleware, HTTPResponseMiddleware,
  @unchecked
  Sendable

{
  private let exporter: (any TraceExporter)?
  private let spanStorage = SpanStorage()

  /// Actor-based storage for active spans.
  private actor SpanStorage {
    var activeSpans: [UUID: TraceSpan] = [:]

    func store(_ span: TraceSpan, for requestId: UUID) {
      activeSpans[requestId] = span
    }

    func retrieve(for requestId: UUID) -> TraceSpan? {
      activeSpans.removeValue(forKey: requestId)
    }
  }

  /// Creates a tracing middleware.
  ///
  /// - Parameter exporter: Optional trace exporter for sending span data
  public init(exporter: (any TraceExporter)? = nil) {
    self.exporter = exporter
  }

  public func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
    let context = TraceContext()
    let span = TraceSpan(name: "\(request.method.rawValue) \(request.url.path)", context: context)

    // HTTP semantic convention attributes
    await span.setAttribute(HTTPSemanticAttributes.httpMethod, request.method.rawValue)
    await span.setAttribute(HTTPSemanticAttributes.httpUrl, request.url.absoluteString)
    await span.setAttribute(HTTPSemanticAttributes.httpHost, request.url.host ?? "unknown")
    await span.setAttribute(HTTPSemanticAttributes.httpPath, request.url.path)
    await span.setAttribute(HTTPSemanticAttributes.httpScheme, request.url.scheme ?? "https")

    if let port = request.url.port {
      await span.setAttribute(HTTPSemanticAttributes.httpPort, String(port))
    }

    if let bodySize = request.body?.count {
      await span.setAttribute(HTTPSemanticAttributes.httpRequestBodySize, String(bodySize))
    }

    if let userAgent = request.headers["User-Agent"] {
      await span.setAttribute(HTTPSemanticAttributes.userAgentOriginal, userAgent)
    }

    // Store span for later retrieval in response processing
    await spanStorage.store(span, for: request.id)

    // Inject W3C trace context headers
    var modifiedRequest = HTTPRequest(
      method: request.method,
      url: request.url,
      headers: request.headers,
      body: request.body,
      timeout: request.timeout
    )

    var newHeaders = modifiedRequest.headers
    newHeaders["traceparent"] = context.traceparent
    if let tracestate = context.tracestateHeader {
      newHeaders["tracestate"] = tracestate
    }

    modifiedRequest = HTTPRequest(
      method: modifiedRequest.method,
      url: modifiedRequest.url,
      headers: newHeaders,
      body: modifiedRequest.body,
      timeout: modifiedRequest.timeout
    )

    return modifiedRequest
  }

  public func processResponse(
    _ response: HTTPResponse,
    for request: HTTPRequest
  ) async throws -> HTTPResponse {
    if let span = await spanStorage.retrieve(for: request.id) {
      // HTTP semantic convention attributes for response
      await span.setAttribute(HTTPSemanticAttributes.httpStatusCode, "\(response.status.rawValue)")

      if let bodySize = response.body?.count {
        await span.setAttribute(HTTPSemanticAttributes.httpResponseBodySize, String(bodySize))
      }

      if response.status.isSuccess {
        await span.end(status: .ok)
      } else {
        await span.end(status: .error("HTTP \(response.status.rawValue)"))
      }

      if let exporter = exporter {
        try? await exporter.export(span)
      }
    }

    return response
  }
}
