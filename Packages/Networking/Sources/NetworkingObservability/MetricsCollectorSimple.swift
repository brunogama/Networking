// swiftlint:disable file_length
import NetworkingRuntime
import Foundation

#if canImport(OSLog)
import OSLog
#endif

#if canImport(OSLog)

// MARK: - Simple In-Memory Collector

/// Simple, lightweight metrics collector for basic use cases
public actor SimpleMetricsCollector: MetricsCollector {
  private var events: [NetworkObservabilityMiddleware.ObservabilityEvent] = []
  private var performanceHistory: [NetworkObservabilityMiddleware.PerformanceMetrics] = []
  private let maxEvents: MaxEventsInMemory
  private let logger: Logger

  public init(maxEvents: MaxEventsInMemory = MaxEventsInMemory(rawValue: 1000)) {
    self.maxEvents = maxEvents
    self.logger = Logger(
      subsystem: "Networking",
      category: "SimpleMetricsCollector"
    )
  }

  public func recordEvent(_ event: NetworkObservabilityMiddleware.ObservabilityEvent) async {
    events.append(event)

    // Keep only recent events
    if events.count > maxEvents.rawValue {
      events.removeFirst(events.count - maxEvents.rawValue)
    }

    logger.debug("Event recorded: \(String(describing: event))")
  }

  public func recordPerformanceMetrics(
    _ metrics: NetworkObservabilityMiddleware.PerformanceMetrics
  ) async {
    performanceHistory.append(metrics)

    // Keep only recent metrics
    if performanceHistory.count > maxEvents.rawValue {
      performanceHistory.removeFirst(performanceHistory.count - maxEvents.rawValue)
    }

    logger.info(
      "Performance: \(metrics.throughput) req/sec, \(String(format: "%.1f", metrics.errorRate.rawValue * 100))% errors"
    )
  }

  /// Returns all recorded events
  public var allEvents: [NetworkObservabilityMiddleware.ObservabilityEvent] {
    get async { events }
  }

  /// Returns all performance metrics
  public var allPerformanceMetrics: [NetworkObservabilityMiddleware.PerformanceMetrics] {
    get async { performanceHistory }
  }

  /// Returns the latest performance metrics
  public var latestMetrics: NetworkObservabilityMiddleware.PerformanceMetrics? {
    get async { performanceHistory.last }
  }

  /// Clears all recorded data
  public func clearAll() async {
    events.removeAll()
    performanceHistory.removeAll()
  }
}

#endif
