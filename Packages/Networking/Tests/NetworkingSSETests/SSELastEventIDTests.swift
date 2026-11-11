import Foundation
import Testing

@testable import NetworkingSSE

extension SSEClientTests {
  @Test(arguments: ["", "next-id"])
  func updatesLastEventIDWithoutData(identifier: String) async throws {
    let (server, url) = try await makeServer(
      path: "/sse/identifier",
      scripts: [
        SSETestResponseScript(chunks: [SSETestChunk("id: \(identifier)\n\n")]),
        SSETestResponseScript(chunks: [SSETestChunk("data: done\n\n")]),
      ]
    )
    defer { server.stop() }
    let configuration = SSEConfiguration(
      reconnectMode: .automatic(
        SSEReconnectPolicy(initialDelay: 0.001, maxDelay: 0.001, maxAttempts: 1)
      ),
      lastEventID: "seed"
    )
    var delivered = 0
    for try await event in makeClient().connect(makeRequest(url: url), configuration: configuration)
    {
      if case .event = event { delivered += 1 }
    }
    let requests = await server.capturedRequests()
    #expect(requests.count == 2)
    #expect(delivered == 1)
    let reconnect = try #require(requests.last)
    #expect(reconnect.headers["Last-Event-ID"] == (identifier.isEmpty ? nil : identifier))
  }
}
