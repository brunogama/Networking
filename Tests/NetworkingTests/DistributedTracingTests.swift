import Testing
import Foundation
@testable import Networking

@Suite("Distributed Tracing Tests")
struct DistributedTracingTests {

  // MARK: - TraceContext Tests

  @Test("TraceContext generates valid trace ID")
  func testTraceIdGeneration() {
    let context = TraceContext()
    #expect(context.traceId.count == 32)
    #expect(context.traceId.allSatisfy { $0.isHexDigit })
  }

  @Test("TraceContext generates valid span ID")
  func testSpanIdGeneration() {
    let context = TraceContext()
    #expect(context.spanId.count == 16)
    #expect(context.spanId.allSatisfy { $0.isHexDigit })
  }

  @Test("TraceContext with default flags is sampled")
  func testDefaultFlagsAreSampled() {
    let context = TraceContext()
    #expect(context.isSampled)
    #expect(context.traceFlags == 0x01)
  }

  @Test("TraceContext with zero flags is not sampled")
  func testZeroFlagsNotSampled() {
    let context = TraceContext(traceFlags: 0x00)
    #expect(!context.isSampled)
  }

  @Test("TraceContext traceparent format")
  func testTraceparentFormat() {
    let context = TraceContext()
    let parts = context.traceparent.split(separator: "-")
    #expect(parts.count == 4)
    #expect(parts[0] == "00")  // version
    #expect(parts[1].count == 32)  // trace-id
    #expect(parts[2].count == 16)  // span-id
    #expect(parts[3].count == 2)  // trace-flags
  }

  @Test("TraceContext tracestate header with entries")
  func testTracestateWithEntries() {
    let context = TraceContext(traceState: ["vendor1": "value1"])
    #expect(context.tracestateHeader?.contains("vendor1=value1") == true)
  }

  @Test("TraceContext tracestate header empty when no entries")
  func testTracestateEmptyWhenNoEntries() {
    let context = TraceContext()
    #expect(context.tracestateHeader == nil)
  }

  @Test("TraceContext child inherits trace ID")
  func testChildInheritsTraceId() {
    let parent = TraceContext()
    let child = parent.createChild()
    #expect(child.traceId == parent.traceId)
    #expect(child.parentSpanId == parent.spanId)
    #expect(child.spanId != parent.spanId)
    #expect(child.traceFlags == parent.traceFlags)
  }

  @Test("TraceContext parse valid traceparent")
  func testParseValidTraceparent() {
    let original = TraceContext()
    let parsed = TraceContext.parse(traceparent: original.traceparent)
    #expect(parsed != nil)
    #expect(parsed?.traceId == original.traceId)
    #expect(parsed?.traceFlags == original.traceFlags)
  }

  @Test("TraceContext parse invalid traceparent returns nil")
  func testParseInvalidTraceparent() {
    #expect(TraceContext.parse(traceparent: "invalid") == nil)
    #expect(TraceContext.parse(traceparent: "00-short-id-01") == nil)
    #expect(TraceContext.parse(traceparent: "01-abc-def-01") == nil)  // wrong version
  }

  @Test("TraceContext equality")
  func testEquality() {
    let context1 = TraceContext(traceId: "a" + String(repeating: "0", count: 31))
    let context2 = TraceContext(traceId: "a" + String(repeating: "0", count: 31))
    // Different span IDs, so not equal
    #expect(context1 != context2)
  }

  // MARK: - TraceSpan Tests

  @Test("TraceSpan records start time")
  func testSpanStartTime() async {
    let context = TraceContext()
    let before = Date()
    let span = TraceSpan(name: "test", context: context)
    let after = Date()

    #expect(span.startTime >= before)
    #expect(span.startTime <= after)
    let isEnded = await span.isEnded
    let duration = await span.duration
    #expect(!isEnded)
    #expect(duration == nil)
  }

  @Test("TraceSpan end records status and time")
  func testSpanEnd() async {
    let context = TraceContext()
    let span = TraceSpan(name: "test", context: context)
    await span.end(status: .ok)

    let isEnded = await span.isEnded
    let duration = await span.duration
    let status = await span.status
    #expect(isEnded)
    #expect(duration != nil)
    #expect(duration! >= 0)
    if case .ok = status {
      // Expected
    } else {
      Issue.record("Expected .ok status")
    }
  }

  @Test("TraceSpan end is idempotent")
  func testSpanEndIdempotent() async {
    let context = TraceContext()
    let span = TraceSpan(name: "test", context: context)
    await span.end(status: .ok)
    let firstEnd = await span.endTime

    await span.end(status: .error("should not override"))
    let currentEnd = await span.endTime
    let status = await span.status
    #expect(currentEnd == firstEnd)
    if case .ok = status {
      // Expected — first end takes precedence
    } else {
      Issue.record("Status should not change after first end")
    }
  }

  @Test("TraceSpan attributes")
  func testSpanAttributes() async {
    let context = TraceContext()
    let span = TraceSpan(name: "test", context: context)
    await span.setAttribute("http.method", "GET")
    await span.setAttribute("http.url", "https://example.com")

    let attributes = await span.attributes
    #expect(attributes["http.method"] == "GET")
    #expect(attributes["http.url"] == "https://example.com")
  }

  @Test("TraceSpan events")
  func testSpanEvents() async {
    let context = TraceContext()
    let span = TraceSpan(name: "test", context: context)
    await span.addEvent(TraceSpan.SpanEvent(name: "retry", attributes: ["attempt": "2"]))
    await span.addEvent(TraceSpan.SpanEvent(name: "success"))

    let events = await span.events
    #expect(events.count == 2)
    #expect(events[0].name == "retry")
    #expect(events[0].attributes["attempt"] == "2")
    #expect(events[1].name == "success")
  }

  // MARK: - TracingMiddleware Tests

  @Test("TracingMiddleware injects traceparent header")
  func testMiddlewareInjectsTraceparent() async throws {
    let middleware = TracingMiddleware()
    let request = HTTPRequest(
      method: .get,
      url: URL(string: "https://api.example.com/users")!
    )

    let processed = try await middleware.modifyRequest(request)
    #expect(processed.headers["traceparent"] != nil)

    // Verify traceparent format
    let traceparent = processed.headers["traceparent"]!
    let parts = traceparent.split(separator: "-")
    #expect(parts.count == 4)
    #expect(parts[0] == "00")
  }

  @Test("TracingMiddleware processes response")
  func testMiddlewareProcessesResponse() async throws {
    let middleware = TracingMiddleware()
    let request = HTTPRequest(
      method: .get,
      url: URL(string: "https://api.example.com/users")!
    )

    // First process the request to create the span
    let processed = try await middleware.modifyRequest(request)

    // Then process the response
    let response = HTTPResponse(
      request: processed,
      status: .ok,
      headers: [:],
      body: Data()
    )

    let processedResponse = try await middleware.processResponse(response, for: processed)
    #expect(processedResponse.status == .ok)
  }

  @Test("TracingMiddleware with exporter")
  func testMiddlewareWithExporter() async throws {
    let exporter = ConsoleTraceExporter()
    let middleware = TracingMiddleware(exporter: exporter)

    let request = HTTPRequest(
      method: .get,
      url: URL(string: "https://api.example.com/users")!
    )

    let processed = try await middleware.modifyRequest(request)

    let response = HTTPResponse(
      request: processed,
      status: .ok,
      headers: [:],
      body: Data()
    )

    // Should not throw
    _ = try await middleware.processResponse(response, for: processed)
  }

  // MARK: - ID Generation Tests

  @Test("generateTraceId produces unique IDs")
  func testTraceIdUniqueness() {
    let ids = (0..<100).map { _ in TraceContext.generateTraceId() }
    let unique = Set(ids)
    #expect(unique.count == ids.count)
  }

  @Test("generateSpanId produces unique IDs")
  func testSpanIdUniqueness() {
    let ids = (0..<100).map { _ in TraceContext.generateSpanId() }
    let unique = Set(ids)
    #expect(unique.count == ids.count)
  }
}
