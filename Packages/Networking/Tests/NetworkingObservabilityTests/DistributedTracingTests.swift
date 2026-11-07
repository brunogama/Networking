import Foundation
import NetworkingCore
import NetworkingRuntime
import Testing
@testable import NetworkingObservability

@Suite("Retained distributed tracing")
struct DistributedTracingTests {
  @Test("Traceparent preserves remote identity and rejects invalid identifiers")
  func traceparentValidation() throws {
    let header: HTTPHeaderValue = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
    let context = try #require(TraceContext.parse(traceparent: header))
    #expect(context.traceparent == header)
    let child = context.createChild()
    #expect(child.traceId == context.traceId)
    #expect(child.parentSpanId == context.spanId)
    #expect(child.spanId != context.spanId)
    #expect(
      TraceContext.parse(traceparent: "00-00000000000000000000000000000000-0000000000000000-01")
        == nil
    )
    #expect(
      TraceContext.parse(traceparent: "00-zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz-00f067aa0ba902b7-01")
        == nil
    )
  }

  @Test("Concurrent uses of one request preserve identity and finish distinct spans")
  func preservesIdentityAcrossAttempts() async throws {
    let exporter = RecordingTraceExporter()
    let middleware = TracingMiddleware(exporter: exporter)
    let request = HTTPRequest(
      method: .get,
      url: try #require(URL(string: "https://user:password@example.com/private?token=secret")),
      headers: ["Authorization": "secret"]
    )
    let first = try await middleware.modifyRequest(request)
    let second = try await middleware.modifyRequest(request)
    #expect(first.id == request.id)
    #expect(second.id == request.id)
    #expect(first.headers["traceparent"] != second.headers["traceparent"])
    _ = try await middleware.processResponse(HTTPResponse(request: first, status: .ok), for: first)
    _ = try await middleware.processResponse(
      HTTPResponse(request: second, status: .ok),
      for: second
    )
    let snapshots = await exporter.snapshots
    #expect(snapshots.count == 2)
    #expect(await middleware.activeSpanCount == 0)
    #expect(snapshots.allSatisfy { $0.name == "GET" })
    #expect(
      snapshots.allSatisfy { !$0.attributes.values.contains { $0.rawValue.contains("secret") } }
    )
    #expect(snapshots.allSatisfy { $0.attributes["http.url"] == nil })
  }

  @Test("Cancellation cleans up once and preserves the original failure")
  func cancellationCleanup() async throws {
    let exporter = RecordingTraceExporter()
    let middleware = TracingMiddleware(exporter: exporter)
    let request = HTTPRequest(method: .get, url: try #require(URL(string: "https://example.com")))
    let processed = try await middleware.modifyRequest(request)
    let error = HTTPError(category: .cancelled, request: processed)
    await #expect(throws: HTTPError.self) {
      try await middleware.handleError(error, for: processed)
    }
    #expect(await middleware.activeSpanCount == 0)
    #expect(await exporter.snapshots.count == 1)
    await #expect(throws: HTTPError.self) {
      try await middleware.handleError(error, for: processed)
    }
    #expect(await exporter.snapshots.count == 1)
  }

  @Test("HTTP failures record error status and completed spans cannot change")
  func terminalState() async throws {
    let exporter = RecordingTraceExporter()
    let middleware = TracingMiddleware(exporter: exporter)
    let request = try await middleware.modifyRequest(
      HTTPRequest(method: .get, url: try #require(URL(string: "https://example.com")))
    )
    _ = try await middleware.processResponse(
      HTTPResponse(request: request, status: .internalServerError),
      for: request
    )
    let snapshot = try #require(await exporter.snapshots.first)
    #expect(snapshot.status == .error("HTTP 500"))
    let span = TraceSpan(name: "operation", context: TraceContext())
    #expect(await span.end(status: .ok))
    await span.setAttribute("after", "ignored")
    #expect(!(await span.end(status: .error("ignored"))))
    #expect(await span.status == .ok)
    #expect(await span.attributes.isEmpty)
  }
}
