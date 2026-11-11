import NetworkingCore
import NetworkingObservability

/// Captures exported spans and optionally injects a delivery failure.
public actor MockTraceExporter: TraceExporter, MockVerifiable {
  private var spans: [TraceSpan] = []
  private var attempts = 0
  private var failure: (any Error)?

  public init() {}

  public func stubSuccess() { failure = nil }

  public func stubFailure(_ error: any Error) { failure = error }

  public func export(_ span: TraceSpan) throws {
    attempts += 1
    if let failure { throw failure }
    spans.append(span)
  }

  public var callCount: MockVerificationCount { MockVerificationCount(attempts) }

  public func getExportedSpans() -> [TraceSpan] { spans }

  public func verifySpanExported(withName name: TraceSpanName) throws(MockError) {
    guard spans.contains(where: { $0.name == name }) else {
      throw .unexpectedArgument(description: "No matching span was exported")
    }
  }

  public func reset() {
    spans.removeAll()
    attempts = 0
    failure = nil
  }
}
