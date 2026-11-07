import Foundation
import NetworkingCore
import NetworkingObservability
import Testing

@Suite("Request measurement collection")
struct MetricsCollectorTests {
  @Test("Invalid measurements are rejected before collection")
  func rejectsInvalidDuration() {
    #expect(throws: HTTPRequestMetrics.ValidationError.invalidDuration) {
      try HTTPRequestMetrics(duration: MeasurementDuration(-1), outcome: .failure)
    }
    #expect(throws: HTTPRequestMetrics.ValidationError.invalidDuration) {
      try HTTPRequestMetrics(duration: MeasurementDuration(.infinity), outcome: .success)
    }
  }

  @Test("Bounded collectors retain newest samples and zero capacity retains none")
  func boundedRetention() async throws {
    let first = try HTTPRequestMetrics(duration: 1, outcome: .success)
    let second = try HTTPRequestMetrics(duration: 2, outcome: .failure)
    let collector = SimpleMetricsCollector(capacity: 1)
    await collector.record(first)
    await collector.record(second)
    #expect(await collector.samples == [second])
    await collector.clear()
    #expect(await collector.samples.isEmpty)
    let disabled = SimpleMetricsCollector(capacity: 0)
    await disabled.record(first)
    #expect(await disabled.samples.isEmpty)
  }
}
