extension HTTPRequestMetrics {
  /// Invalid external measurement values.
  public enum ValidationError: Error, Sendable, Equatable {
    /// Duration must be finite and nonnegative.
    case invalidDuration
    /// Timestamp must be finite.
    case invalidTimestamp
  }
}
