import NetworkingCore
import NetworkingObservability

/// Records request measurements for deterministic assertions without exporting them.
public actor MockMetricsCollector: MetricsCollector, MockVerifiable {

  public private(set) var samples: [HTTPRequestMetrics] = []

  public init() {}

  public func record(_ metrics: HTTPRequestMetrics) {
    samples.append(metrics)
  }

  public var callCount: MockVerificationCount {
    MockVerificationCount(samples.count)
  }

  public func reset() { samples.removeAll() }
}
