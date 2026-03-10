import Foundation
import NetworkingRuntime

// MARK: - Trace Exporter Protocol

/// Protocol for exporting trace data to external systems.
///
/// Implement this protocol to send span data to backends like Jaeger,
/// Zipkin, or OpenTelemetry collectors.
public protocol TraceExporter: Sendable {
  /// Exports a completed span.
  func export(_ span: TraceSpan) async throws

  /// Flushes any buffered spans.
  func flush() async throws
}

// MARK: - Console Trace Exporter

/// A trace exporter that writes spans to the system logger.
public struct ConsoleTraceExporter: TraceExporter {
  public init() {}

  public func export(_ span: TraceSpan) async throws {
    let durationValue = await span.duration
    let duration = durationValue.map { String(format: "%.3fms", $0.rawValue * 1000) } ?? "active"
    NSLog(
      "[TRACE] %@ | trace=%@... | span=%@... | %@",
      span.name.rawValue,
      String(span.context.traceId.rawValue.prefix(8)),
      String(span.context.spanId.rawValue.prefix(8)),
      duration
    )
  }

  public func flush() async throws {}
}
