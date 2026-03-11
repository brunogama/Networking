import NetworkingRuntime
import Foundation

#if canImport(OSLog)
import OSLog

/// Protocol for collecting and aggregating network metrics and observability events.
/// This is the core interface for all metrics collection implementations.
public protocol MetricsCollector: Sendable {
  /// Records an observability event
  /// - Parameter event: The event to record
  func recordEvent(_ event: NetworkObservabilityMiddleware.ObservabilityEvent) async

  /// Records performance metrics snapshot
  /// - Parameter metrics: The performance metrics to record
  func recordPerformanceMetrics(_ metrics: NetworkObservabilityMiddleware.PerformanceMetrics) async
}

// Comprehensive metrics collector that provides advanced analytics, persistence, and real-time
// monitoring.
public actor ComprehensiveMetricsCollector: MetricsCollector {
  let configuration: Configuration
  let logger: Logger

  var events: [EventRecord] = []
  var performanceSnapshots: [NetworkObservabilityMiddleware.PerformanceMetrics] = []
  var businessMetricsHistory: [BusinessMetrics] = []
  var metricsWindows: [MetricsWindow] = []
  var activeAlerts: [Alert] = []

  var dailyUsers: Set<String> = []
  var activeSessions: Set<String> = []
  var sessionStartTimes: [String: Date] = [:]
  var lastCleanup = Date()

  public init(configuration: Configuration = Configuration()) {
    self.configuration = configuration
    self.logger = Logger(
      subsystem: "Networking",
      category: "MetricsCollector"
    )

    if configuration.enablePersistence.rawValue, let directory = configuration.persistenceDirectory
    {
      try? FileManager.default.createDirectory(
        at: directory.rawValue,
        withIntermediateDirectories: true,
        attributes: nil
      )
    }
  }

  // swiftlint:disable:next cyclomatic_complexity
  public func recordEvent(_ event: NetworkObservabilityMiddleware.ObservabilityEvent) async {
    var sessionId: SessionIdentifier?
    var userId: UserIdentifier?

    switch event {
    case .requestStarted(let context):
      sessionId = context.sessionId
      userId = context.userId

    case .requestCompleted(let context, _):
      sessionId = context.sessionId
      userId = context.userId

    case .requestFailed(let context, _):
      sessionId = context.sessionId
      userId = context.userId

    default:
      break
    }

    let eventRecord = EventRecord(
      event: event,
      sessionId: sessionId,
      userId: userId
    )

    events.append(eventRecord)

    if configuration.enableBusinessMetrics.rawValue {
      await updateBusinessTracking(for: eventRecord)
    }

    if let processor = configuration.eventProcessors[
      ObservabilityTagName(String(describing: type(of: event)))
    ] {
      await processor(eventRecord)
    }

    if configuration.enableAlerting.rawValue {
      await checkForAlerts(event: event)
    }

    await performPeriodicMaintenance()

    logger.debug("Recorded event: \(eventRecord.eventId)")
  }

  public func recordPerformanceMetrics(
    _ metrics: NetworkObservabilityMiddleware.PerformanceMetrics
  ) async {
    performanceSnapshots.append(metrics)

    if configuration.enableAlerting.rawValue {
      await checkPerformanceAlerts(metrics)
    }

    await updateMetricsWindows(with: metrics)

    if configuration.enablePersistence.rawValue {
      await persistMetrics(metrics)
    }

    logger.info(
      "Performance metrics recorded: \(metrics.throughput) req/sec, \(String(format: "%.1f", metrics.errorRate.rawValue * 100))% errors"
    )
  }
}

#endif  // canImport(OSLog)
