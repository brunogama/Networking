// swiftlint:disable file_length
import NetworkingRuntime
import Foundation

#if canImport(OSLog)

// MARK: - Convenience Factories

extension NetworkObservabilityMiddleware {
  /// Creates observability middleware with standard configuration
  /// - Parameters:
  ///   - metricsCollector: The metrics collector to use
  ///   - enableRealTimeMetrics: Whether to enable real-time performance monitoring
  /// - Returns: Configured observability middleware
  public static func standard(
    metricsCollector: any MetricsCollector,
    enableRealTimeMetrics: EnableRealtimeMetricsFlag = true
  ) -> NetworkObservabilityMiddleware {
    let configuration = Configuration(enableRealTimeMetrics: enableRealTimeMetrics)
    return NetworkObservabilityMiddleware(
      configuration: configuration,
      metricsCollector: metricsCollector
    )
  }

  /// Creates observability middleware with production configuration
  /// - Parameters:
  ///   - metricsCollector: The metrics collector to use
  ///   - samplingRate: Tracing sampling rate (0.0 to 1.0)
  /// - Returns: Configured observability middleware
  public static func production(
    metricsCollector: any MetricsCollector,
    samplingRate: TracingSampleRate = 0.1
  ) -> NetworkObservabilityMiddleware {
    let configuration = Configuration(
      tracingSampleRate: samplingRate,
      metricsReportingInterval: 300.0,
      enableRealTimeMetrics: true
    )
    return NetworkObservabilityMiddleware(
      configuration: configuration,
      metricsCollector: metricsCollector
    )
  }

  /// Creates observability middleware for development/debugging
  /// - Parameter metricsCollector: The metrics collector to use
  /// - Returns: Configured observability middleware with full tracing
  public static func development(
    metricsCollector: any MetricsCollector
  ) -> NetworkObservabilityMiddleware {
    let configuration = Configuration(
      tracingSampleRate: 1.0,
      metricsReportingInterval: 30.0,
      redactedHeaders: [],  // Don't redact headers in development
      enableRealTimeMetrics: true
    )
    return NetworkObservabilityMiddleware(
      configuration: configuration,
      metricsCollector: metricsCollector
    )
  }
}

#endif  // canImport(OSLog)
