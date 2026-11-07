/// Exports completed trace spans within the caller's task lifetime.
public protocol TraceExporter: Sendable {

  func export(_ span: TraceSpan) async throws
}
