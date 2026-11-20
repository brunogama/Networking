import Foundation
import Networking

struct SSEBenchmark: Sendable {
  private let context: BenchmarkContext

  init(context: BenchmarkContext) {
    self.context = context
  }

  func run() async throws -> BenchmarkResult {
    context.diagnostics.clear()
    let request = context.makeRequest("sse")
    let start = ContinuousClock.now
    let eventCount = try await consumeEvents(request)
    let duration = BenchmarkTiming.seconds(start.duration(to: .now))
    try BenchmarkIntegrity.validateCount(
      eventCount,
      matches: SSEBenchmarkFixture.eventCount,
      operation: "SSE"
    )
    let measurement = BenchmarkMeasurement(
      name: "SSE / \(eventCount) events (one stream)",
      samplesMilliseconds: [duration * 1_000],
      bytesTransferred: Int64(eventCount * SSEBenchmarkFixture.eventLineBytes),
      durationSeconds: duration
    )
    return context.makeResult(measurement)
  }

  private func consumeEvents(_ request: HTTPRequest) async throws -> Int {
    var eventCount = 0
    let configuration = SSEConfiguration(
      reconnectMode: .disabled,
      maxBufferedEvents: SSEBenchmarkFixture.bufferedEventCount
    )
    let eventClient = context.clients.events
    let stream = eventClient.connect(
      request,
      configuration: configuration
    )
    for try await connectionEvent in stream {
      guard case .event(let event) = connectionEvent else { continue }
      try BenchmarkIntegrity.validatePayload(
        event.data.rawValue,
        matches: SSEBenchmarkFixture.eventPayload,
        operation: "SSE"
      )
      eventCount += 1
    }
    return eventCount
  }
}

// Shared by normal and backpressure SSE workloads.
enum SSEBenchmarkFixture {
  static let eventCount = 1_000
  static let eventPayload = "0123456789abcdef0123456789abcdef"
  static let eventLineBytes = eventPayload.utf8.count + 8
  static let bufferedEventCount = eventCount + 100
}
