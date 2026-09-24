import Foundation
import Testing

@testable import NetworkingSSE

extension SSEClientTests {
  func makeReconnectServer() async throws -> (SSETestServer, URL) {
    try await makeServer(
      path: "/sse/reconnect",
      scripts: [
        SSETestResponseScript(
          chunks: [
            SSETestChunk("id: 42\n"),
            SSETestChunk("retry: 20\n"),
            SSETestChunk("data: first\n\n"),
          ]
        ),
        SSETestResponseScript(
          chunks: [SSETestChunk("data: second\n\n")]
        ),
      ]
    )
  }

  func assertReconnect(
    _ event: SSEConnectionEvent,
    attempt: Int,
    delay: TimeInterval
  ) {
    guard case .reconnecting(let actualAttempt, let actualDelay) = event else {
      Issue.record("Expected reconnecting event")
      return
    }

    #expect(actualAttempt == attempt)
    #expect(abs(actualDelay.rawValue - delay) < 0.000_1)
  }
}
