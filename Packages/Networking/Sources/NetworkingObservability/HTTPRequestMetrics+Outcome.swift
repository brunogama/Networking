extension HTTPRequestMetrics {
  /// Whether the completed request succeeded or failed.
  public enum Outcome: String, Sendable {

    case success

    case failure
  }
}
