extension HTTPRequestMetrics {
  /// Invalid external measurement values.
  public enum ValidationError: Error, Sendable, Equatable {

    case invalidDuration

    case invalidTimestamp
  }
}
