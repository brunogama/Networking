import NetworkingCore

/// Retains a bounded history of completed request measurements.
public actor SimpleMetricsCollector: MetricsCollector {
  private let capacity: Int
  /// Recorded measurements ordered from oldest to newest.
  public private(set) var samples: [HTTPRequestMetrics] = []

  /// Creates a collector; nonpositive capacity disables retention.
  public init(capacity: RequestCount = 1_000) {
    self.capacity = max(0, capacity.rawValue)
  }

  /// Appends one sample and evicts the oldest sample when full.
  public func record(_ metrics: HTTPRequestMetrics) {
    guard capacity > 0 else { return }
    if samples.count == capacity { samples.removeFirst() }
    samples.append(metrics)
  }

  /// Removes retained measurements.
  public func clear() { samples.removeAll() }
}
