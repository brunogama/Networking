import NetworkingRuntime
import Foundation

#if canImport(OSLog)
import OSLog

extension ComprehensiveMetricsCollector {
  public func getEvents(from startDate: Date, to endDate: Date) async -> [EventRecord] {
    events.filter { event in
      event.timestamp >= startDate && event.timestamp <= endDate
    }
  }

  public func getPerformanceSnapshots(
    from startDate: Date,
    to endDate: Date
  ) async -> [NetworkObservabilityMiddleware.PerformanceMetrics] {
    performanceSnapshots.filter { snapshot in
      snapshot.timestamp >= startDate && snapshot.timestamp <= endDate
    }
  }

  public var currentAlerts: [Alert] {
    get async {
      activeAlerts.filter { Date().timeIntervalSince($0.timestamp) < 3600 }
    }
  }

  public var currentBusinessMetrics: BusinessMetrics {
    get async {
      let sessionDurations = sessionStartTimes.compactMap { sessionId, startTime in
        activeSessions.contains(sessionId) ? Date().timeIntervalSince(startTime) : nil
      }

      let averageSessionDuration =
        sessionDurations.isEmpty
        ? 0 : sessionDurations.reduce(0, +) / Double(sessionDurations.count)

      return BusinessMetrics(
        dailyActiveUsers: DailyActiveUserCount(dailyUsers.count),
        totalSessions: SessionCount(activeSessions.count),
        averageSessionDuration: MeasurementDuration(averageSessionDuration)
      )
    }
  }

  public var timeWindowMetrics: [MetricsWindow] {
    get async { metricsWindows }
  }

  public func clearAllMetrics() async {
    events.removeAll()
    performanceSnapshots.removeAll()
    businessMetricsHistory.removeAll()
    metricsWindows.removeAll()
    activeAlerts.removeAll()
    dailyUsers.removeAll()
    activeSessions.removeAll()
    sessionStartTimes.removeAll()

    logger.info("All metrics cleared")
  }
}

#endif  // canImport(OSLog)
