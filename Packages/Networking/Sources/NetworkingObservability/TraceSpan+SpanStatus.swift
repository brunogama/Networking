import NetworkingCore

extension TraceSpan {
  /// Terminal span status.
  public enum SpanStatus: Sendable, Equatable {

    case unset

    case ok

    case error(SpanStatusMessage)
  }
}
