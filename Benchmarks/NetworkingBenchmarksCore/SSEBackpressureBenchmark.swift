import Foundation
import Networking

struct SSEBackpressureBenchmark: Sendable {
  private let context: BenchmarkContext

  init(context: BenchmarkContext) {
    self.context = context
  }

  func run() async throws -> BenchmarkResult {
    context.diagnostics.clear()
    let start = ContinuousClock.now
    let eventCount = try await consumeSlowly()
    let duration = BenchmarkTiming.seconds(start.duration(to: .now))
    let measurement = BenchmarkMeasurement(
      name: "SSE slow consumer / buffer 32 / overflow after \(eventCount) events",
      samplesMilliseconds: [duration * 1_000],
      bytesTransferred: Int64(eventCount * SSEBenchmarkFixture.eventLineBytes),
      durationSeconds: duration
    )
    return context.makeResult(measurement)
  }

  private func consumeSlowly() async throws -> Int {
    let request = context.makeRequest("sse")
    let configuration = SSEConfiguration(
      reconnectMode: .disabled,
      maxBufferedEvents: TransferProgressWorkload.sseBufferSize
    )
    return try await consume(request, configuration: configuration)
  }

  private func consume(
    _ request: HTTPRequest,
    configuration: SSEConfiguration
  ) async throws -> Int {
    var deliveredEvents = 0
    do {
      let eventClient = context.clients.events
      let stream = eventClient.connect(
        request,
        configuration: configuration
      )
      for try await connectionEvent in stream {
        guard case .event(let event) = connectionEvent else { continue }
        deliveredEvents += 1
        try await consumeEvent(event)
      }
    } catch SSEStreamError.bufferOverflow {
      return deliveredEvents
    }
    throw TransferProgressBenchmarkFailure.backpressureNotObserved
  }

  private func consumeEvent(_ event: SSEEvent) async throws {
    try BenchmarkIntegrity.validatePayload(
      event.data.rawValue,
      matches: SSEBenchmarkFixture.eventPayload,
      operation: "SSE backpressure"
    )
    try await Task.sleep(for: TransferProgressWorkload.consumerDelay)
  }
}
