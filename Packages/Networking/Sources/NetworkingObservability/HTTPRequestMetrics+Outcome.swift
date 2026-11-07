extension HTTPRequestMetrics {
  /// Whether the completed request succeeded or failed.
  public enum Outcome: String, Sendable {
    /// The request completed successfully.
    case success
    /// The request failed, including HTTP failure and cancellation.
    case failure
  }
}
