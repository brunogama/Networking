/// Receives completed request measurements within the caller's task lifetime.
public protocol MetricsCollector: Sendable {

  func record(_ metrics: HTTPRequestMetrics) async throws
}
