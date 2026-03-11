import NetworkingRuntime
import Foundation

#if canImport(OSLog)
import OSLog

extension ComprehensiveMetricsCollector {
  // swiftlint:disable:next cyclomatic_complexity
  func checkForAlerts(event: NetworkObservabilityMiddleware.ObservabilityEvent) async {
    switch event {
    case .requestFailed(_, let errorContext):
      if errorContext.errorType == "network" {
        let alert = Alert(
          level: .warning,
          title: "Network Error Detected",
          message: "Network connectivity issue: \(errorContext.errorMessage)"
        )
        await recordAlert(alert)
      }

    case .circuitBreakerTripped(let endpoint, let reason):
      let alert = Alert(
        level: .error,
        title: "Circuit Breaker Tripped",
        message: "Circuit breaker activated for endpoint \(endpoint): \(reason)"
      )
      await recordAlert(alert)

    case .rateLimitHit(_, let limit, _):
      let alert = Alert(
        level: .warning,
        title: "Rate Limit Exceeded",
        message: "Rate limit of \(limit) requests exceeded"
      )
      await recordAlert(alert)

    default:
      break
    }
  }

  // swiftlint:disable:next function_body_length
  func checkPerformanceAlerts(
    _ metrics: NetworkObservabilityMiddleware.PerformanceMetrics
  ) async {
    if metrics.errorRate.rawValue * 100 > configuration.alertThresholds.errorRateThreshold.rawValue
    {
      let alert = Alert(
        level: .error,
        title: "High Error Rate",
        message: AlertMessage(
          "Error rate is \(String(format: "%.1f", metrics.errorRate.rawValue * 100))%"
        ),
        metric: "error_rate",
        value: AlertThresholdValue(metrics.errorRate.rawValue * 100),
        threshold: configuration.alertThresholds.errorRateThreshold
      )
      await recordAlert(alert)
    }

    if metrics.averageResponseTime > configuration.alertThresholds.responseTimeThreshold {
      let alert = Alert(
        level: .warning,
        title: "High Response Time",
        message: AlertMessage(
          "Average response time is \(Int(metrics.averageResponseTime.rawValue * 1000))ms"
        ),
        metric: "response_time",
        value: AlertThresholdValue(metrics.averageResponseTime.rawValue),
        threshold: AlertThresholdValue(configuration.alertThresholds.responseTimeThreshold.rawValue)
      )
      await recordAlert(alert)
    }

    if metrics.throughput < configuration.alertThresholds.throughputThreshold {
      let alert = Alert(
        level: .info,
        title: "Low Throughput",
        message: AlertMessage(
          "Throughput is \(String(format: "%.2f", metrics.throughput.rawValue)) req/sec"
        ),
        metric: "throughput",
        value: AlertThresholdValue(metrics.throughput.rawValue),
        threshold: AlertThresholdValue(configuration.alertThresholds.throughputThreshold.rawValue)
      )
      await recordAlert(alert)
    }

    if metrics.activeConnections > configuration.alertThresholds.maxActiveConnections {
      let alert = Alert(
        level: .critical,
        title: "High Connection Count",
        message: "\(metrics.activeConnections) active connections",
        metric: "active_connections",
        value: AlertThresholdValue(Double(metrics.activeConnections.rawValue)),
        threshold: AlertThresholdValue(
          Double(configuration.alertThresholds.maxActiveConnections.rawValue)
        )
      )
      await recordAlert(alert)
    }
  }

  func recordAlert(_ alert: Alert) async {
    activeAlerts.append(alert)

    let cutoffTime = Date().addingTimeInterval(-3600)
    activeAlerts.removeAll { $0.timestamp < cutoffTime }

    logger.log(
      level: logLevelForAlert(alert.level),
      "\(alert.level.label): \(alert.title) - \(alert.message)"
    )
  }

  func logLevelForAlert(_ level: AlertLevel) -> OSLogType {
    switch level {
    case .info: return .info
    case .warning: return .error
    case .error: return .error
    case .critical: return .fault
    }
  }
}

#endif  // canImport(OSLog)
