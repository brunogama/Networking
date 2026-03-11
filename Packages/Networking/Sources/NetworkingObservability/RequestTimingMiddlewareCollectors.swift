import NetworkingRuntime
import Foundation

#if canImport(OSLog)
import OSLog
#endif

/// A metrics collector that stores metrics in memory
public actor MemoryMetricsCollector: RequestTimingMiddleware.MetricsCollector {
  private var metrics: [RequestTimingMiddleware.RequestMetrics] = []
  private let maxMetricsCount: MetricsRecordLimit

  /// Creates a new memory metrics collector
  /// - Parameter maxMetricsCount: Maximum number of metrics to store
  public init(maxMetricsCount: MetricsRecordLimit = MetricsRecordLimit(rawValue: 1000)) {
    self.maxMetricsCount = maxMetricsCount
  }

  public func recordMetrics(_ metrics: RequestTimingMiddleware.RequestMetrics) async {
    // Remove oldest metrics if we exceed the limit
    if self.metrics.count >= maxMetricsCount.rawValue {
      let metricsToRemove = self.metrics.count - maxMetricsCount.rawValue + 1
      self.metrics.removeFirst(metricsToRemove)
    }

    self.metrics.append(metrics)
  }

  /// Returns all recorded metrics
  public var allMetrics: [RequestTimingMiddleware.RequestMetrics] {
    get async { metrics }
  }

  /// Returns metrics for successful requests only
  public var successfulRequests: [RequestTimingMiddleware.RequestMetrics] {
    get async { metrics.filter { $0.isSuccess.rawValue } }
  }

  /// Returns metrics for failed requests only
  public var failedRequests: [RequestTimingMiddleware.RequestMetrics] {
    get async { metrics.filter { !$0.isSuccess } }
  }

  /// Returns average response time for successful requests
  public var averageResponseTime: MeasurementDuration {
    get async {
      let successfulMetrics = metrics.filter { $0.isSuccess.rawValue }
      guard !successfulMetrics.isEmpty else { return MeasurementDuration(0) }

      let totalDuration = successfulMetrics.reduce(MeasurementDuration(0)) { $0 + $1.duration }
      return MeasurementDuration(totalDuration.rawValue / Double(successfulMetrics.count))
    }
  }

  /// Returns the 95th percentile response time
  public var p95ResponseTime: MeasurementDuration {
    get async {
      let successfulMetrics = metrics.filter { $0.isSuccess.rawValue }
      guard !successfulMetrics.isEmpty else { return MeasurementDuration(0) }

      let sortedDurations = successfulMetrics.map(\.duration).sorted()
      let index = Int(Double(sortedDurations.count) * 0.95)
      return sortedDurations[min(index, sortedDurations.count - 1)]
    }
  }

  /// Clears all recorded metrics
  public func clearMetrics() async {
    metrics.removeAll()
  }
}

/// A metrics collector that logs metrics to the console
public struct LoggingMetricsCollector: RequestTimingMiddleware.MetricsCollector {
  private let logLevel: LogLevel
  private let formatter: @Sendable (RequestTimingMiddleware.RequestMetrics) -> UserMessageText
  #if canImport(OSLog)
  private let logger: Logger
  #endif

  public enum LogLevel: Sendable {
    case debug
    case info
    case warning
    case error

    public var label: UserMessageText {
      switch self {
      case .debug: return "DEBUG"
      case .info: return "INFO"
      case .warning: return "WARNING"
      case .error: return "ERROR"
      }
    }
  }

  /// Creates a new logging metrics collector
  /// - Parameters:
  ///   - logLevel: The log level to use
  ///   - formatter: Custom formatter for log messages
  public init(
    logLevel: LogLevel = .info,
    formatter: @escaping @Sendable (RequestTimingMiddleware.RequestMetrics) -> UserMessageText =
      Self.defaultFormatter
  ) {
    self.logLevel = logLevel
    self.formatter = formatter
    #if canImport(OSLog)
    self.logger = Logger(
      subsystem: "Networking",
      category: "RequestTimingMetrics"
    )
    #endif
  }

  public func recordMetrics(_ metrics: RequestTimingMiddleware.RequestMetrics) async {
    let message = formatter(metrics)
    #if canImport(OSLog)
    logger.info("[\(logLevel.label)] \(message)")
    #endif
  }

  public static func defaultFormatter(
    _ metrics: RequestTimingMiddleware.RequestMetrics
  ) -> UserMessageText {
    let status: UserMessageText = metrics.isSuccess.rawValue ? "SUCCESS" : "FAILED"
    let durationMs = Int(metrics.duration.rawValue * 1000)

    var parts = [
      "\(metrics.request.method.rawValue) \(metrics.request.url.absoluteString)",
      "\(status) in \(durationMs)ms",
    ]

    if let statusCode = metrics.statusCode {
      parts.append("status: \(statusCode)")
    }

    if let bodySize = metrics.responseBodySize {
      parts.append("size: \(bodySize) bytes")
    }

    return UserMessageText(parts.joined(separator: " | "))
  }
}

/// A composite metrics collector that forwards to multiple collectors
public struct CompositeMetricsCollector: RequestTimingMiddleware.MetricsCollector {
  private let collectors: [any RequestTimingMiddleware.MetricsCollector]

  /// Creates a composite metrics collector
  /// - Parameter collectors: The collectors to forward metrics to
  public init(collectors: [any RequestTimingMiddleware.MetricsCollector]) {
    self.collectors = collectors
  }

  public func recordMetrics(_ metrics: RequestTimingMiddleware.RequestMetrics) async {
    // Record metrics in all collectors concurrently
    await withTaskGroup(of: Void.self) { group in
      for collector in collectors {
        group.addTask {
          await collector.recordMetrics(metrics)
        }
      }
    }
  }
}

// MARK: - Convenience Factory

extension RequestTimingMiddleware {
  /// Creates a timing middleware with memory-based metrics collection
  /// - Parameters:
  ///   - maxMetricsCount: Maximum number of metrics to store in memory
  ///   - configuration: Optional custom configuration
  /// - Returns: A configured timing middleware and its metrics collector
  public static func withMemoryCollector(
    maxMetricsCount: MetricsRecordLimit = 1000,
    configuration: Configuration = Configuration()
  ) -> (middleware: RequestTimingMiddleware, collector: MemoryMetricsCollector) {
    let collector = MemoryMetricsCollector(maxMetricsCount: maxMetricsCount)
    let middleware = RequestTimingMiddleware(
      configuration: configuration,
      metricsCollector: collector
    )
    return (middleware, collector)
  }

  /// Creates a timing middleware with console logging
  /// - Parameters:
  ///   - logLevel: The log level to use
  ///   - configuration: Optional custom configuration
  /// - Returns: A configured timing middleware
  public static func withLogging(
    logLevel: LoggingMetricsCollector.LogLevel = .info,
    configuration: Configuration = Configuration()
  ) -> RequestTimingMiddleware {
    let collector = LoggingMetricsCollector(logLevel: logLevel)
    return RequestTimingMiddleware(
      configuration: configuration,
      metricsCollector: collector
    )
  }

  /// Creates a timing middleware with both memory and logging collectors
  /// - Parameters:
  ///   - maxMetricsCount: Maximum number of metrics to store in memory
  ///   - logLevel: The log level to use for console output
  ///   - configuration: Optional custom configuration
  /// - Returns: A configured timing middleware and its memory collector
  public static func withMemoryAndLogging(
    maxMetricsCount: MetricsRecordLimit = 1000,
    logLevel: LoggingMetricsCollector.LogLevel = .info,
    configuration: Configuration = Configuration()
  ) -> (middleware: RequestTimingMiddleware, collector: MemoryMetricsCollector) {
    let memoryCollector = MemoryMetricsCollector(maxMetricsCount: maxMetricsCount)
    let loggingCollector = LoggingMetricsCollector(logLevel: logLevel)
    let compositeCollector = CompositeMetricsCollector(
      collectors: [memoryCollector, loggingCollector]
    )

    let middleware = RequestTimingMiddleware(
      configuration: configuration,
      metricsCollector: compositeCollector
    )

    return (middleware, memoryCollector)
  }
}
