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
    let measurement = BenchmarkMeasurement(
      name: "SSE / \(eventCount) events (one stream)",
      samplesMilliseconds: [duration * 1_000],
      bytesTransferred: Int64(eventCount * 40),
      durationSeconds: duration
    )
    return context.makeResult(measurement)
  }

  private func consumeEvents(_ request: HTTPRequest) async throws -> Int {
    var eventCount = 0
    let configuration = SSEConfiguration(
      reconnectMode: .disabled,
      maxBufferedEvents: 1_100
    )
    let eventClient = context.clients.events
    let stream = eventClient.connect(
      request,
      configuration: configuration
    )
    for try await event in stream {
      guard case .event = event else { continue }
      eventCount += 1
    }
    return eventCount
  }
}
