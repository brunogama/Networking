import Foundation
import NetworkingCore
import Testing

@testable import NetworkingSSE

@Suite("SSE POST requests")
struct SSEPostTests {
  @Test("Explicitly enabled POST streams without replay")
  func enabledPost() async throws {
    let (server, url) = try await makeServer(
      path: "/sse/post",
      scripts: [SSETestResponseScript(chunks: [SSETestChunk("data: hello\n\n")])]
    )
    defer { server.stop() }
    let stream = makeClient().connect(
      makeRequest(url: url, method: .post),
      configuration: .init(reconnectMode: .disabled, allowPostRequests: true)
    )
    var events: [SSEConnectionEvent] = []
    for try await event in stream { events.append(event) }
    #expect(events.contains(.event(SSEEvent(data: "hello"))))
    let requests = await server.capturedRequests()
    #expect(requests.count == 1)
    #expect(requests.first?.method == "POST")
  }

  @Test("POST with automatic reconnect fails before connecting")
  func postCannotAutomaticallyReplay() async throws {
    let url = try #require(URL(string: "http://127.0.0.1:1/"))
    let stream = makeClient().connect(
      makeRequest(url: url, method: .post),
      configuration: .init(allowPostRequests: true)
    )
    do {
      for try await _ in stream {}
      Issue.record("Expected invalid configuration")
    } catch SSEStreamError.invalidConfiguration {}
  }
}
