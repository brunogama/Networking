import NetworkingRuntime
import Foundation

// MARK: - Performance Testing Extensions

extension MockNetworkClient {
  /// Measure the performance of a request
  /// - Parameter request: The request to measure
  /// - Returns: Performance metrics
  public func measurePerformance(for request: HTTPRequest) async throws -> PerformanceMetrics {
    let startTime = Date()
    let startMemory = getCurrentMemoryUsage()

    let response = try await execute(request)

    let duration = MeasurementDuration(Date().timeIntervalSince(startTime))
    let endMemory = getCurrentMemoryUsage()

    return PerformanceMetrics(
      duration: duration,
      memoryDelta: StorageSizeValue(endMemory - startMemory),
      responseSize: ResponseSize((response.body?.count ?? 0).rawValue)
    )
  }

  private func getCurrentMemoryUsage() -> Int {
    #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(
      MemoryLayout.size(ofValue: info) / MemoryLayout<integer_t>.size
    )
    let result = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
        task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
      }
    }
    return result == KERN_SUCCESS ? Int(info.resident_size) : 0
    #else
    // On Linux, memory tracking is not available via this method
    return 0
    #endif
  }
}

// MARK: - Performance Metrics

public struct PerformanceMetrics {
  public let duration: MeasurementDuration
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
