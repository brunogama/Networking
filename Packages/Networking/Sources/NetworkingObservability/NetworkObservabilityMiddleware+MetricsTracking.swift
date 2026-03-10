import NetworkingRuntime
import Foundation

#if canImport(OSLog)
import OSLog

extension NetworkObservabilityMiddleware {
  func updatePerformanceMetrics(
    duration: TimeInterval,
    success: Bool,
    endpoint: String,
    error: String?
  ) async {
    let now = Date()
    requestHistory.append(
      RequestSample(timestamp: now, duration: duration, wasSuccessful: success)
    )

    let cutoffTime = now.addingTimeInterval(-configuration.metricsRetentionDuration.rawValue)
    requestHistory.removeAll { $0.timestamp < cutoffTime }

    if endpointPerformance[endpoint] == nil {
      endpointPerformance[endpoint] = []
    }
    endpointPerformance[endpoint]?.append(duration)

    if let measurements = endpointPerformance[endpoint], measurements.count > 1000 {
      endpointPerformance[endpoint] = Array(measurements.suffix(1000))
    }

    if let error {
      errorCounts[error] = (errorCounts[error] ?? 0) + 1
    }
  }

  func reportPerformanceMetrics() async {
    let metrics = await calculatePerformanceMetrics()
    await metricsCollector.recordPerformanceMetrics(metrics)

    logger.info(
      """
      Performance metrics: \(metrics.throughput) req/sec, \
      \(Int(metrics.averageResponseTime.rawValue * 1000))ms avg, \
      \(String(format: "%.1f", metrics.errorRate.rawValue * 100))% error rate
      """
    )
  }

  // swiftlint:disable:next function_body_length
  func calculatePerformanceMetrics() async -> PerformanceMetrics {
    let now = Date()
    let recentRequests = requestHistory.filter {
      now.timeIntervalSince($0.timestamp) <= 300
    }

    let totalRequests = recentRequests.count
    let successfulRequests = recentRequests.filter(\.wasSuccessful).count
    let failedRequests = totalRequests - successfulRequests

    let durations = recentRequests.map(\.duration).sorted()
    let averageResponseTime =
      durations.isEmpty ? 0 : durations.reduce(0, +) / Double(durations.count)

    let p50Index = Int(Double(durations.count) * 0.5)
    let p95Index = Int(Double(durations.count) * 0.95)
    let p99Index = Int(Double(durations.count) * 0.99)

    let p50ResponseTime = durations.isEmpty ? 0 : durations[min(p50Index, durations.count - 1)]
    let p95ResponseTime = durations.isEmpty ? 0 : durations[min(p95Index, durations.count - 1)]
    let p99ResponseTime = durations.isEmpty ? 0 : durations[min(p99Index, durations.count - 1)]

    let errorRate =
      totalRequests == 0
      ? 0
      : Double(failedRequests) / Double(totalRequests)
    let throughput =
      totalRequests == 0
      ? 0
      : Double(totalRequests) / 300.0

    let sortedErrorCounts = Array(
      errorCounts
        .sorted { $0.value > $1.value }
        .prefix(10)
    )
    let topErrors = Dictionary(uniqueKeysWithValues: sortedErrorCounts)

    let topSlowEndpoints = Array(
      endpointPerformance.compactMap { endpoint, times -> (String, TimeInterval)? in
        guard !times.isEmpty else { return nil }
        let avgTime = times.reduce(0, +) / Double(times.count)
        return (endpoint, avgTime)
      }
      .sorted { $0.1 > $1.1 }
      .prefix(10)
    )

    let networkHealth = calculateNetworkHealth(
      errorRate: errorRate,
      averageLatency: averageResponseTime,
      p95Latency: p95ResponseTime,
      throughput: throughput
    )

    return PerformanceMetrics(
      timestamp: now,
      totalRequests: RequestCount(totalRequests),
      successfulRequests: RequestCount(successfulRequests),
      failedRequests: RequestCount(failedRequests),
      averageResponseTime: MeasurementDuration(averageResponseTime),
      p50ResponseTime: MeasurementDuration(p50ResponseTime),
      p95ResponseTime: MeasurementDuration(p95ResponseTime),
      p99ResponseTime: MeasurementDuration(p99ResponseTime),
      errorRate: ErrorRateValue(errorRate),
      throughput: ThroughputValue(throughput),
      activeConnections: ActiveConnectionCount(activeTraces.count),
      cacheHitRate: CacheHitRateValue(0.0),
      retryRate: RetryRateValue(0.0),
      topErrors: Dictionary(
        uniqueKeysWithValues: topErrors.map {
          (ObservabilityErrorType($0.key), RequestCount($0.value))
        }
      ),
      topSlowEndpoints: topSlowEndpoints.map {
        PerformanceMetrics.SlowEndpoint(
          endpoint: EndpointIdentifier($0.0),
          averageResponseTime: MeasurementDuration($0.1)
        )
      },
      networkHealth: networkHealth
    )
  }

  public var currentMetrics: PerformanceMetrics {
    get async {
      await calculatePerformanceMetrics()
    }
  }

  public var activeTraceCount: ActiveTraceCount {
    get async { ActiveTraceCount(activeTraces.count) }
  }

  public func clearObservabilityData() async {
    activeTraces.removeAll()
    requestHistory.removeAll()
    errorCounts.removeAll()
    endpointPerformance.removeAll()
  }
}

#endif  // canImport(OSLog)
