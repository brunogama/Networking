import Foundation
import NetworkingCore
import NetworkingRuntime
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

    let session = makeSession()
    defer { session.invalidateAndCancel() }
    let diagnostics = NetworkDiagnostics(logs: .none)
    let changes = diagnostics.changes()
    let client = SSEClient(session: session, diagnostics: diagnostics)
    let stream = client.connect(
      makeRequest(url: url),
      configuration: SSEConfiguration(reconnectMode: .disabled, maxBufferedEvents: 1)
    )
    for await _ in changes where diagnostics.traces.first?.endedAt != nil {
      break
    }
    var iterator = stream.makeAsyncIterator()

    do {
      while try await iterator.next() != nil {}
      Issue.record("Expected the stream buffer to overflow")
    } catch SSEStreamError.bufferOverflow {}
  }
  @Test("Oversized SSE responses fail before yielding their event")
  func oversizedResponseFails() async throws {
    let (server, url) = try await makeServer(
      path: "/sse/too-large",
      scripts: [SSETestResponseScript(chunks: [SSETestChunk("data: oversized\n\n")])]
    )
    defer { server.stop() }
    let stream = makeClient().connect(
      makeRequest(url: url),
      configuration: SSEConfiguration(
        reconnectMode: .disabled,
        maxBufferedEvents: 8,
        maximumResponseBytes: 8
      )
    )
    var receivedEvent = false
    do {
      for try await event in stream {
        if case .event = event { receivedEvent = true }
      }
      Issue.record("Expected the stream to exceed its byte limit")
    } catch SSEStreamError.responseTooLarge {
      #expect(!receivedEvent)
    }
  }

  @Test("An SSE response exactly at the byte limit is accepted")
  func responseAtLimit() async throws {
    let payload = "data: x\n\n"
    let (server, url) = try await makeServer(
      path: "/sse/at-limit",
      scripts: [SSETestResponseScript(chunks: [SSETestChunk(payload)])]
    )
    defer { server.stop() }
    let stream = makeClient().connect(
      makeRequest(url: url),
      configuration: .init(
        reconnectMode: .disabled,
        maxBufferedEvents: 8,
        maximumResponseBytes: payload.utf8.count
      )
    )
    var receivedEvent = false
    for try await event in stream {
      if case .event = event { receivedEvent = true }
    }
    #expect(receivedEvent)
  }

  @Test("A negative SSE response limit is rejected")
  func negativeLimitRejected() async throws {
    let url = try #require(URL(string: "http://127.0.0.1:1/"))
    let stream = makeClient().connect(
      makeRequest(url: url),
      configuration: .init(reconnectMode: .disabled, maximumResponseBytes: -1)
    )
    do {
      for try await _ in stream {}
      Issue.record("Expected invalid configuration")
    } catch SSEStreamError.invalidConfiguration {
      // The invalid limit is rejected before connecting.
    }
  }

}
