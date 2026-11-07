/// Receives completed request measurements within the caller's task lifetime.
public protocol MetricsCollector: Sendable {
  /// Records a measurement; export failures and cancellation propagate to the caller.
  func record(_ metrics: HTTPRequestMetrics) async throws
}
