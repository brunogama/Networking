import NetworkingCore

/// Retains a bounded history of completed request measurements.
public actor SimpleMetricsCollector: MetricsCollector {
  private let capacity: Int

  public private(set) var samples: [HTTPRequestMetrics] = []

  public init(capacity: RequestCount = 1_000) {
    self.capacity = max(0, capacity.rawValue)
  }

  public func record(_ metrics: HTTPRequestMetrics) {
    guard capacity > 0 else { return }
    if samples.count == capacity { samples.removeFirst() }
    samples.append(metrics)
  }

  public func clear() { samples.removeAll() }
}
