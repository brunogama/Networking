import NetworkingCore
import NetworkingObservability

/// Records request measurements for deterministic assertions without exporting them.
public actor MockMetricsCollector: MetricsCollector, MockVerifiable {
  /// Measurements received since initialization or the last reset.
  public private(set) var samples: [HTTPRequestMetrics] = []

  /// Creates an empty collector.
  public init() {}

  /// Records a completed request measurement.
  public func record(_ metrics: HTTPRequestMetrics) {
    samples.append(metrics)
  }

  /// The number of recorded measurements.
  public var callCount: MockVerificationCount {
    MockVerificationCount(samples.count)
  }

  /// Discards recorded measurements.
  public func reset() { samples.removeAll() }
}
