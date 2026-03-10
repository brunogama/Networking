// swiftlint:disable file_length
import NetworkingRuntime
import Foundation

#if canImport(OSLog)
import OSLog
#endif

#if canImport(OSLog)

// MARK: - Console Logging Collector

/// Metrics collector that outputs all events and metrics to the console
public struct ConsoleMetricsCollector: MetricsCollector {
  private let logger: Logger
  private let formatter:
    @Sendable (NetworkObservabilityMiddleware.ObservabilityEvent) -> UserMessageText

  public init(
    formatter:
      @escaping @Sendable (NetworkObservabilityMiddleware.ObservabilityEvent) -> UserMessageText =
      Self.defaultFormatter
  ) {
    self.logger = Logger(
      subsystem: "Networking",
      category: "ConsoleMetricsCollector"
    )
    self.formatter = formatter
  }

  public func recordEvent(_ event: NetworkObservabilityMiddleware.ObservabilityEvent) async {
    let message = formatter(event)
    logger.info("EVENT: \(message)")
  }

  public func recordPerformanceMetrics(
    _ metrics: NetworkObservabilityMiddleware.PerformanceMetrics
  ) async {
    logger.info(
      "METRICS: \(metrics.throughput) req/sec | \(Int(metrics.averageResponseTime.rawValue * 1000))ms avg | \(String(format: "%.1f", metrics.errorRate.rawValue * 100))% errors | Health: \(metrics.networkHealth.status.label)"
    )
  }

  // swiftlint:disable:next cyclomatic_complexity
  public static func defaultFormatter(
    _ event: NetworkObservabilityMiddleware.ObservabilityEvent
  ) -> UserMessageText {
    switch event {
    case .requestStarted(let context):
      return "REQUEST_STARTED: \(context.method) \(context.path)"

    case .requestCompleted(let context, let response):
      return
        UserMessageText(
          "REQUEST_COMPLETED: \(context.method) \(context.path) [\(response.statusCode)] in \(Int(response.duration.rawValue * 1000))ms"
        )

    case .requestFailed(let context, let error):
      return
        "REQUEST_FAILED: \(context.method) \(context.path) - \(error.errorType): \(error.errorMessage)"

    case .requestRetried(let context, let attempt):
      return "REQUEST_RETRIED: \(context.method) \(context.path) (attempt \(attempt))"

    case .circuitBreakerTripped(let endpoint, let reason):
      return "CIRCUIT_BREAKER_TRIPPED: \(endpoint) - \(reason)"

    case .cacheHit(let context, let cacheKey):
      return "CACHE_HIT: \(context.path) [\(cacheKey)]"

    case .cacheMiss(let context, let cacheKey):
      return "CACHE_MISS: \(context.path) [\(cacheKey)]"

    case .rateLimitHit(let context, let limit, let window):
      return "RATE_LIMIT_HIT: \(context.path) [\(limit) requests per \(window)s]"

    case .authenticationsRefreshed(let context):
      return "AUTH_REFRESHED: \(context.path)"

    case .middlewareError(let context, let middlewareName, let error):
      return "MIDDLEWARE_ERROR: \(middlewareName) on \(context.path) - \(error)"
    }
  }
}

#endif
