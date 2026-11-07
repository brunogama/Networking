import Foundation
import NetworkingCore

/// A validated W3C version-00 trace context.
public struct TraceContext: Sendable, Equatable {
  /// A 32-character nonzero lowercase hexadecimal trace identifier.
  public let traceId: TraceIdentifier
  /// A 16-character nonzero lowercase hexadecimal span identifier.
  public let spanId: SpanIdentifier
  /// The parent span identifier, if this is a locally created child.
  public let parentSpanId: SpanIdentifier?
  /// Propagated trace flags.
  public let traceFlags: TraceFlags

  /// Creates a new sampled root trace.
  public init() {
    self.init(trace: Self.generateTraceId(), span: Self.generateSpanId(), parent: nil, flags: 1)
  }

  private init(trace: TraceIdentifier, span: SpanIdentifier, parent: SpanIdentifier?, flags: Int) {
    self.traceId = trace
    self.spanId = span
    self.parentSpanId = parent
    self.traceFlags = TraceFlags(flags)
  }

  /// Whether the sampled bit is set.
  public var isSampled: TraceSampledFlag {
    TraceSampledFlag(traceFlags.rawValue & 1 != 0)
  }

  /// The W3C traceparent header value.
  public var traceparent: HTTPHeaderValue {
    HTTPHeaderValue(
      "00-\(traceId.rawValue)-\(spanId.rawValue)-\(String(format: "%02x", traceFlags.rawValue))"
    )
  }

  /// Creates a child with the same trace identifier and this span as its parent.
  public func createChild() -> Self {
    Self(trace: traceId, span: Self.generateSpanId(), parent: spanId, flags: traceFlags.rawValue)
  }

  /// Parses a version-00 traceparent without changing its trace or span identity.
  public static func parse(traceparent header: HTTPHeaderValue) -> Self? {
    let parts = header.rawValue.split(separator: "-", omittingEmptySubsequences: false)
    guard parts.count == 4, parts[0] == "00" else { return nil }
    guard validIdentifier(parts[1], count: 32), validIdentifier(parts[2], count: 16) else {
      return nil
    }
    guard parts[3].count == 2, parts[3].allSatisfy(isLowerHex),
      let flags = UInt8(parts[3], radix: 16)
    else { return nil }
    return Self(
      trace: TraceIdentifier(String(parts[1])),
      span: SpanIdentifier(String(parts[2])),
      parent: nil,
      flags: Int(flags)
    )
  }

  /// Generates a nonzero trace identifier.
  public static func generateTraceId() -> TraceIdentifier {
    TraceIdentifier(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased())
  }

  /// Generates a nonzero span identifier.
  public static func generateSpanId() -> SpanIdentifier {
    SpanIdentifier(String(generateTraceId().rawValue.suffix(16)))
  }

  private static func validIdentifier(_ value: Substring, count: Int) -> Bool {
    value.count == count && value.allSatisfy(isLowerHex) && value.contains { $0 != "0" }
  }

  private static func isLowerHex(_ character: Character) -> Bool {
    "0123456789abcdef".contains(character)
  }
}
