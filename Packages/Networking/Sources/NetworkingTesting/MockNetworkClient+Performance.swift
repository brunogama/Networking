import NetworkingRuntime
import Foundation

#if canImport(Darwin)
import Darwin
#endif

// MARK: - Performance Testing Extensions

extension MockNetworkClient {
  /// Measure the performance of a request
  /// - Parameter request: The request to measure
  /// - Returns: Performance metrics
  public func measurePerformance(for request: HTTPRequest) async throws -> PerformanceMetrics {
    let startTime = Date()
    let startMemory = getPeakMemoryUsage()

    let response = try await execute(request)

    let duration = MeasurementDuration(Date().timeIntervalSince(startTime))
    let endMemory = getPeakMemoryUsage()

    return PerformanceMetrics(
      duration: duration,
      memoryDelta: StorageSizeValue(endMemory - startMemory),
      responseSize: ResponseSize((response.body?.count ?? 0).rawValue)
    )
  }

  private func getPeakMemoryUsage() -> Int {
    #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
    var usage = rusage()
    return getrusage(RUSAGE_SELF, &usage) == 0 ? Int(usage.ru_maxrss) : 0
    #else
    return 0
    #endif
  }
}

// MARK: - Performance Metrics

public struct PerformanceMetrics {
  public let duration: MeasurementDuration
  /// Growth in peak resident memory during the request.
  public let memoryDelta: StorageSizeValue
  public let responseSize: ResponseSize

  public var throughput: ThroughputValue {
    guard duration.rawValue > 0 else { return 0 }
    return ThroughputValue(Double(responseSize.rawValue) / duration.rawValue)
  }

  public var description: String {
    """
    Duration: \(String(format: "%.3f", duration.rawValue))s
    Memory Delta: \(memoryDelta.rawValue) bytes
    Response Size: \(responseSize.rawValue) bytes
    Throughput: \(String(format: "%.2f", throughput.rawValue)) bytes/s
    """
  }
}
