import Foundation
import NetworkingCore
import Testing

@testable import NetworkingSSE

@Suite("SSE buffer limits")
struct SSEOverflowTests {
  @Test("A slow SSE consumer receives an overflow error instead of losing events silently")
  func slowConsumerFailsOnOverflow() async throws {
    let (server, url) = try await makeServer(
      path: "/sse/overflow",
      scripts: [
        SSETestResponseScript(chunks: [
          SSETestChunk("data: first\n\n"),
          SSETestChunk("data: second\n\n"),
        ])
      ]
    )
    defer { server.stop() }

    let client = makeClient()
    let stream = client.connect(
      makeRequest(url: url),
      configuration: SSEConfiguration(reconnectMode: .disabled, maxBufferedEvents: 1)
    )
    try await Task.sleep(for: .milliseconds(100))
    var iterator = stream.makeAsyncIterator()

    await #expect(throws: SSEStreamError.self) {
      while try await iterator.next() != nil {}
    }
  }

}
