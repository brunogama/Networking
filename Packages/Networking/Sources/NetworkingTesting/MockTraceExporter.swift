import NetworkingCore
import NetworkingObservability

/// Captures exported spans and optionally injects a delivery failure.
public actor MockTraceExporter: TraceExporter, MockVerifiable {
  private var spans: [TraceSpan] = []
  private var attempts = 0
  private var failure: (any Error)?

  /// Creates an empty exporter that accepts spans.
  public init() {}

  /// Makes subsequent exports succeed.
  public func stubSuccess() { failure = nil }

  /// Makes subsequent exports throw the supplied failure.
  public func stubFailure(_ error: any Error) { failure = error }

  /// Records an attempt, then throws the configured failure or retains the span.
  public func export(_ span: TraceSpan) throws {
    attempts += 1
    if let failure { throw failure }
    spans.append(span)
  }

  /// Export attempts, including failed deliveries.
  public var callCount: MockVerificationCount { MockVerificationCount(attempts) }

  /// Successfully exported spans, in delivery order.
  public func getExportedSpans() -> [TraceSpan] { spans }

  /// Requires at least one successfully exported span with this name.
  /// - Throws: A mock verification error if no matching span exists.
  public func verifySpanExported(withName name: TraceSpanName) throws(MockError) {
    guard spans.contains(where: { $0.name == name }) else {
      throw .unexpectedArgument(description: "No matching span was exported")
    }
  }

  /// Clears captured spans, attempts, and any configured failure.
  public func reset() {
    spans.removeAll()
    attempts = 0
    failure = nil
  }
}
