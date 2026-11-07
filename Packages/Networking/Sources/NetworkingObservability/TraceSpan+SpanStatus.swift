import NetworkingCore

extension TraceSpan {
  /// Terminal span status.
  public enum SpanStatus: Sendable, Equatable {
    /// No outcome recorded.
    case unset
    /// Successful operation.
    case ok
    /// Failed operation with a caller-sanitized message.
    case error(SpanStatusMessage)
  }
}
