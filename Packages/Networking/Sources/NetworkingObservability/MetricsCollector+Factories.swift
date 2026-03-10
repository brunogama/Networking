import NetworkingRuntime
import Foundation

#if canImport(OSLog)
import OSLog

extension ComprehensiveMetricsCollector {
  /// Creates a collector with production configuration
  public static func production(
    persistenceDirectory: PersistenceDirectory? = nil
  ) -> ComprehensiveMetricsCollector {
    let config = Configuration(
      maxEventsInMemory: 50_000,
      eventRetentionDuration: 86_400,  // 24 hours
      enablePersistence: EnablePersistenceFlag(persistenceDirectory != nil),
      persistenceDirectory: persistenceDirectory,
      enableAlerting: true,
      enableBusinessMetrics: true
    )
    return ComprehensiveMetricsCollector(configuration: config)
  }

  /// Creates a collector for development/testing
  public static func development() -> ComprehensiveMetricsCollector {
    let config = Configuration(
      maxEventsInMemory: 1000,
      eventRetentionDuration: 3600,  // 1 hour
      enablePersistence: false,
      enableAlerting: false,
      enableBusinessMetrics: true
    )
    return ComprehensiveMetricsCollector(configuration: config)
  }

  /// Creates a collector with custom alert thresholds
  public static func withCustomAlerts(
    errorRateThreshold: AlertThresholdValue = 5.0,
    responseTimeThreshold: MeasurementDuration = 2.0,
    throughputThreshold: ThroughputValue = 0.1
  ) -> ComprehensiveMetricsCollector {
    let alertThresholds = AlertThresholds(
      errorRateThreshold: errorRateThreshold,
      responseTimeThreshold: responseTimeThreshold,
      throughputThreshold: throughputThreshold
    )

    let config = Configuration(
      enableAlerting: true,
      alertThresholds: alertThresholds
    )

    return ComprehensiveMetricsCollector(configuration: config)
  }
}

#endif  // canImport(OSLog)
