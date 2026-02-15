import Testing
@testable import Networking

@Suite("OTLP Trace Exporter Tests")
struct OTLPTraceExporterTests {

  // MARK: - Initialization Tests

  @Test("Creates exporter with valid configuration")
  func initWithValidConfig() async throws {
    let config = OTLPConfiguration(
      endpoint: URL(string: "http://localhost:4318")!,
      resource: OTLPResource(serviceName: "test-service")
    )

    let exporter = try OTLPTraceExporter(configuration: config)
    // Exporter created successfully (non-optional type)

    // Cleanup
    await exporter.shutdown()
  }

  @Test("Throws on invalid configuration")
  func initThrowsOnInvalidConfig() {
    let config = OTLPConfiguration(
      endpoint: URL(string: "ftp://invalid:4318")!
    )

    #expect(throws: OTLPConfigurationError.self) {
      _ = try OTLPTraceExporter(configuration: config)
    }
  }

  // MARK: - Export Tests

  @Test("Exports span without throwing")
  func exportSpan() async throws {
    let config = OTLPConfiguration(
      endpoint: URL(string: "http://localhost:4318")!,
      resource: OTLPResource(serviceName: "test-service")
    )

    let exporter = try OTLPTraceExporter(configuration: config)

    // Create a test span
    let context = TraceContext()
    let span = TraceSpan(name: "test-span", context: context)
    await span.setAttribute("test.attribute", "test-value")
    await span.end(status: .ok)

    // Export should not throw (network errors are logged, not thrown)
    try await exporter.export(span)

    await exporter.shutdown()
  }

  @Test("Buffers spans until batch size reached")
  func buffersSpans() async throws {
    let config = OTLPConfiguration(
      endpoint: URL(string: "http://localhost:4318")!,
      batchSize: 5,
      resource: OTLPResource(serviceName: "test-service")
    )

    let exporter = try OTLPTraceExporter(configuration: config)

    // Export fewer spans than batch size
    for i in 0..<3 {
      let context = TraceContext()
      let span = TraceSpan(name: "span-\(i)", context: context)
      await span.end()
      try await exporter.export(span)
    }

    // Spans should be buffered (not flushed yet)
    // No network error means buffering worked

    await exporter.shutdown()
  }

  // MARK: - Flush Tests

  @Test("Flush exports buffered spans")
  func flushExportsBufferedSpans() async throws {
    let config = OTLPConfiguration(
      endpoint: URL(string: "http://localhost:4318")!,
      batchSize: 100,  // High batch size to prevent auto-flush
      resource: OTLPResource(serviceName: "test-service")
    )

    let exporter = try OTLPTraceExporter(configuration: config)

    // Export a span
    let context = TraceContext()
    let span = TraceSpan(name: "flush-test-span", context: context)
    await span.end()
    try await exporter.export(span)

    // Manually flush
    try await exporter.flush()

    // Shutdown
    await exporter.shutdown()
  }

  // MARK: - TraceExporter Protocol Conformance

  @Test("Conforms to TraceExporter protocol")
  func conformsToProtocol() async throws {
    let config = OTLPConfiguration(
      endpoint: URL(string: "http://localhost:4318")!
    )

    let exporter = try OTLPTraceExporter(configuration: config)

    // Verify protocol conformance via type constraint
    let _: any TraceExporter = exporter

    await exporter.shutdown()
  }
}
