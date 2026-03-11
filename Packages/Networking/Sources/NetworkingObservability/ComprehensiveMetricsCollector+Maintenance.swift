import NetworkingRuntime
import Foundation

#if canImport(OSLog)
import OSLog

extension ComprehensiveMetricsCollector {
  // swiftlint:disable:next cyclomatic_complexity
  func updateBusinessTracking(for eventRecord: EventRecord) async {
    switch eventRecord.event {
    case .requestStarted(let context):
      if let userId = context.userId {
        dailyUsers.insert(userId.rawValue)
      }

      if let sessionId = context.sessionId {
        activeSessions.insert(sessionId.rawValue)
        if sessionStartTimes[sessionId.rawValue] == nil {
          sessionStartTimes[sessionId.rawValue] = eventRecord.timestamp
        }
      }

    case .requestCompleted:
      break

    default:
      break
    }
  }

  func updateMetricsWindows(
    with metrics: NetworkObservabilityMiddleware.PerformanceMetrics
  ) async {
    let windowStart = Date().addingTimeInterval(-configuration.metricsWindowSize.rawValue)
    let windowEnd = Date()

    let window = MetricsWindow(
      windowStart: windowStart,
      windowEnd: windowEnd,
      totalRequests: metrics.totalRequests,
      successfulRequests: metrics.successfulRequests,
      failedRequests: metrics.failedRequests,
      averageResponseTime: metrics.averageResponseTime,
      p50ResponseTime: metrics.p50ResponseTime,
      p95ResponseTime: metrics.p95ResponseTime,
      p99ResponseTime: metrics.p99ResponseTime,
      errorRate: metrics.errorRate,
      throughput: metrics.throughput,
      topErrors: metrics.topErrors,
      endpointStats: [:]
    )

    metricsWindows.append(window)

    let cutoffTime = Date().addingTimeInterval(-configuration.eventRetentionDuration.rawValue)
    metricsWindows.removeAll { $0.windowEnd < cutoffTime }
  }

  func performPeriodicMaintenance() async {
    let now = Date()

    guard now.timeIntervalSince(lastCleanup) >= 300 else { return }
    lastCleanup = now

    let cutoffTime = now.addingTimeInterval(-configuration.eventRetentionDuration.rawValue)

    events.removeAll { $0.timestamp < cutoffTime }
    if events.count > configuration.maxEventsInMemory.rawValue {
      events = Array(events.suffix(configuration.maxEventsInMemory.rawValue))
    }

    performanceSnapshots.removeAll { $0.timestamp < cutoffTime }

    for (sessionId, startTime) in sessionStartTimes
    where now.timeIntervalSince(startTime) > 86_400 {
      sessionStartTimes.removeValue(forKey: sessionId)
      activeSessions.remove(sessionId)
    }

    let calendar = Calendar.current
    if calendar.component(.hour, from: now) == 0 && calendar.component(.minute, from: now) < 5 {
      dailyUsers.removeAll()
    }

    logger.debug(
      "Maintenance completed: \(self.events.count) events, \(self.performanceSnapshots.count) snapshots"
    )
  }
}

#endif  // canImport(OSLog)
