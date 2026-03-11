import NetworkingRuntime
import Foundation

#if canImport(OSLog)
import OSLog

extension ComprehensiveMetricsCollector {
  func persistMetrics(_ metrics: NetworkObservabilityMiddleware.PerformanceMetrics) async {
    guard let directory = configuration.persistenceDirectory else { return }

    let filename = "metrics-\(Int(metrics.timestamp.timeIntervalSince1970)).json"
    let fileURL = directory.rawValue.appendingPathComponent(filename)

    do {
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601

      let persistableMetrics = PersistableMetrics(from: metrics)
      let data = try encoder.encode(persistableMetrics)
      try data.write(to: fileURL)
    } catch {
      logger.error("Failed to persist metrics: \(error.localizedDescription)")
    }
  }

  public func exportMetrics(from startDate: Date, to endDate: Date) async -> HTTPBody? {
    struct ExportData: Codable {
      let exportTimestamp: Date
      let events: Int
      let performanceSnapshots: Int
      let businessMetrics: BusinessMetrics
      let alertCount: Int
    }

    let exportData = ExportData(
      exportTimestamp: Date(),
      events: await getEvents(from: startDate, to: endDate).count,
      performanceSnapshots: await getPerformanceSnapshots(from: startDate, to: endDate).count,
      businessMetrics: await currentBusinessMetrics,
      alertCount: await currentAlerts.count
    )

    do {
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      return HTTPBody(try encoder.encode(exportData))
    } catch {
      logger.error("Failed to export metrics: \(error.localizedDescription)")
      return nil
    }
  }
}

private extension ComprehensiveMetricsCollector {
  struct PersistableMetrics: Codable {
    let timestamp: Date
    let totalRequests: Int
    let successfulRequests: Int
    let failedRequests: Int
    let averageResponseTime: TimeInterval
    let errorRate: Double
    let throughput: Double

    init(from metrics: NetworkObservabilityMiddleware.PerformanceMetrics) {
      self.timestamp = metrics.timestamp
      self.totalRequests = metrics.totalRequests.rawValue
      self.successfulRequests = metrics.successfulRequests.rawValue
      self.failedRequests = metrics.failedRequests.rawValue
      self.averageResponseTime = metrics.averageResponseTime.rawValue
      self.errorRate = metrics.errorRate.rawValue
      self.throughput = metrics.throughput.rawValue
    }
  }
}

#endif  // canImport(OSLog)
