/// Exports completed trace spans within the caller's task lifetime.
public protocol TraceExporter: Sendable {
  /// Sends one completed span, propagating export failure and cancellation.
  func export(_ span: TraceSpan) async throws
}
