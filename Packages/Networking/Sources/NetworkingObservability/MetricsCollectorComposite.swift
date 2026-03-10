// swiftlint:disable file_length
import NetworkingRuntime
import Foundation

#if canImport(OSLog)

// MARK: - Composite Collector

/// Collector that forwards events to multiple collectors for observability
public struct ObservabilityCompositeMetricsCollector: MetricsCollector {
  private let collectors: [any MetricsCollector]

  public init(collectors: [any MetricsCollector]) {
    self.collectors = collectors
  }

  public func recordEvent(_ event: NetworkObservabilityMiddleware.ObservabilityEvent) async {
    // Record in all collectors concurrently
    await withTaskGroup(of: Void.self) { group in
      for collector in collectors {
        group.addTask {
          await collector.recordEvent(event)
        }
      }
    }
  }

  public func recordPerformanceMetrics(
    _ metrics: NetworkObservabilityMiddleware.PerformanceMetrics
  ) async {
    // Record in all collectors concurrently
    await withTaskGroup(of: Void.self) { group in
      for collector in collectors {
        group.addTask {
          await collector.recordPerformanceMetrics(metrics)
        }
      }
    }
  }
}

#endif
