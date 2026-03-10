import Foundation
import NetworkingCore
import Testing

@testable import NetworkingSSE

private actor ObservedSSEEvents {
  private var events: [SSEConnectionEvent] = []

  func append(_ event: SSEConnectionEvent) {
    events.append(event)
  }

  func contains(_ event: SSEConnectionEvent) -> Bool {
    events.contains(event)
  }

  func snapshot() -> [SSEConnectionEvent] {
    events
  }
}

@Suite("SSEClient")
struct SSEClientTests {
  @Test("Connect emits open, parsed events, and closed on graceful completion")
  func connectEmitsOpenEventsAndClosed() async throws {
    let (server, url) = try await makeServer(
      path: "/sse/basic",
      scripts: [
        SSETestResponseScript(
          chunks: [
            SSETestChunk("id: 1\n"),
            SSETestChunk("event: message\n"),
            SSETestChunk("data: hello\n\n"),
            SSETestChunk("data: world\n\n"),
          ]
        )
      ]
    )
    defer { server.stop() }

    let client = makeClient()
    var iterator = client.connect(
      makeRequest(url: url),
      configuration: SSEConfiguration(reconnectMode: .disabled)
    ).makeAsyncIterator()

    #expect(try await iterator.next() == .open)
    #expect(
      try await iterator.next()
        == .event(SSEEvent(id: "1", event: "message", data: "hello"))
    )
    #expect(
      try await iterator.next()
        == .event(SSEEvent(data: "world"))
    )
    #expect(try await iterator.next() == .closed)
    #expect(try await iterator.next() == nil)
  }

  @Test("Connect fails when the endpoint is not text/event-stream")
  func connectFailsForInvalidContentType() async {
    let serverAndURL = try? await makeServer(
      path: "/sse/invalid-content-type",
      scripts: [
        SSETestResponseScript(
          headers: ["Content-Type": "application/json"],
          chunks: [SSETestChunk("{\"ok\":true}")]
        )
      ]
    )
    guard let (server, url) = serverAndURL else {
      Issue.record("Failed to start the invalid-content-type SSE test server")
      return
    }
    defer { server.stop() }

    let client = makeClient()
    var iterator = client.connect(
      makeRequest(url: url),
      configuration: SSEConfiguration(reconnectMode: .disabled)
    ).makeAsyncIterator()

    do {
      _ = try await iterator.next()
      Issue.record("Expected SSE content type validation to fail")
    } catch let error as HTTPError {
      guard case .custom(let type, let message) = error.category else {
        Issue.record("Expected a custom SSE error")
        return
      }

      #expect(type == "SSE")
      #expect(message.contains("text/event-stream"))
    } catch {
      Issue.record("Expected HTTPError, got \(type(of: error))")
    }
  }

  @Test("Connect applies request middleware and SSE headers before opening")
  func connectAppliesRequestMiddlewareAndHeaders() async throws {
    let (server, url) = try await makeServer(
      path: "/sse/headers",
      scripts: [
        SSETestResponseScript(
          chunks: [SSETestChunk("data: ok\n\n")]
        )
      ]
    )
    defer { server.stop() }

    let client = SSEClient(
      session: makeSession(),
      requestMiddlewares: [AuthorizationMiddleware(token: "secret-token")]
    )
    var iterator = client.connect(
      makeRequest(url: url),
      configuration: SSEConfiguration(
        reconnectMode: .disabled,
        lastEventID: "seed-event"
      )
    ).makeAsyncIterator()

    #expect(try await iterator.next() == .open)
    _ = try await iterator.next()
    _ = try await iterator.next()

    let capturedRequests = await server.capturedRequests()
    let request = try #require(capturedRequests.first)

    #expect(request.headers["Authorization"] == "Bearer secret-token")
    #expect(request.headers["Accept"] == "text/event-stream")
    #expect(request.headers["Cache-Control"] == "no-cache")
    #expect(request.headers["Last-Event-ID"] == "seed-event")
  }

  @Test("Connect reconnects with Last-Event-ID and server retry hints")
  func connectReconnectsWithLastEventID() async throws {
    let (server, url) = try await makeReconnectServer()
    defer { server.stop() }
    let client = makeClient()
    let configuration = SSEConfiguration(
      reconnectMode: .automatic(
        SSEReconnectPolicy(initialDelay: 0.001, maxDelay: 0.05, maxAttempts: 1)
      )
    )
    var iterator = client.connect(makeRequest(url: url), configuration: configuration)
      .makeAsyncIterator()

    #expect(try await iterator.next() == .open)
    let firstEvent = try #require(try await iterator.next())
    let reconnecting = try #require(try await iterator.next())
    #expect(try await iterator.next() == .open)
    let secondEvent = try #require(try await iterator.next())
    #expect(try await iterator.next() == .closed)
    #expect(try await iterator.next() == nil)

    #expect(
      firstEvent == .event(SSEEvent(id: "42", data: "first", retry: 0.02))
    )
    assertReconnect(reconnecting, attempt: 1, delay: 0.02)
    #expect(secondEvent == .event(SSEEvent(data: "second")))

    let capturedRequests = await server.capturedRequests()
    let secondRequest = try #require(capturedRequests.dropFirst().first)
    #expect(secondRequest.headers["Last-Event-ID"] == "42")
  }

  @Test("Connect stops promptly when the consuming task is cancelled")
  func connectStopsWhenCancelled() async throws {
    let (server, url) = try await makeServer(
      path: "/sse/cancel",
      scripts: [
        SSETestResponseScript(
          chunks: [
            SSETestChunk("data: first\n\n"),
            SSETestChunk("data: delayed\n\n", delay: 1.0),
          ]
        )
      ]
    )
    defer { server.stop() }

    let client = makeClient()
    let stream = client.connect(
      makeRequest(url: url),
      configuration: SSEConfiguration(reconnectMode: .disabled)
    )
    let observedEvents = ObservedSSEEvents()

    let consumer = Task {
      do {
        for try await event in stream {
          await observedEvents.append(event)
        }
      } catch {
        // The consumer task may observe cancellation while waiting on the stream.
      }
    }

    for _ in 0..<50 {
      if await observedEvents.contains(.open) {
        break
      }

      try await Task.sleep(for: .milliseconds(10))
    }

    consumer.cancel()
    _ = await consumer.value
    let snapshot = await observedEvents.snapshot()

    #expect(snapshot.contains(SSEConnectionEvent.open))
  }
}

private extension SSEClientTests {
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
