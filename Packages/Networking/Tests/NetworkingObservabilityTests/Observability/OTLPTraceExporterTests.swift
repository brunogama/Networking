import Foundation
import NetworkingCore
import NetworkingObservability
import OpenTelemetryProtocolExporterCommon
import Testing
@testable import NetworkingObservabilityOTLP

@Suite("OTLP trace protobuf export")
struct OTLPTraceExporterTests {
  @Test("Wire payload preserves identifiers, events, resources, and redaction")
  func preservesTraceWireData() async throws {
    let fixture = try OTLPTestFixture()
    let context = TraceContext().createChild()
    let span = TraceSpan(name: "GET", context: context, startTime: Date(timeIntervalSince1970: 1))
    await span.setAttribute("http.request.header.authorization", "secret")
    await span.setAttribute("safe", "visible")
    await span.addEvent(
      .init(
        name: "received",
        timestamp: Date(timeIntervalSince1970: 1.5),
        attributes: ["user.token": "secret"]
      )
    )
    await span.end(endTime: Date(timeIntervalSince1970: 2))
    let exporter = try OTLPTraceExporter(
      configuration: fixture.configuration,
      session: fixture.session
    )
    let data = try exporter.payload(await span.snapshot())
    let decoded = try Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest(
      serializedBytes: data
    )
    let resource = try #require(decoded.resourceSpans.first)
    let exported = try #require(resource.scopeSpans.first?.spans.first)
    #expect(exported.traceID == hexData(context.traceId.rawValue))
    #expect(exported.spanID == hexData(context.spanId.rawValue))
    #expect(exported.parentSpanID == context.parentSpanId.map { hexData($0.rawValue) })
    #expect(exported.startTimeUnixNano == 1_000_000_000)
    #expect(exported.endTimeUnixNano == 2_000_000_000)
    #expect(exported.attributes.map(\.key) == ["safe"])
    #expect(exported.events.first?.name == "received")
    #expect(exported.events.first?.attributes.isEmpty == true)
    #expect(resource.resource.attributes.contains { $0.key == "service.name" })
  }

  @Test("Exporter awaits correct endpoint and surfaces collector rejection")
  func checksCollectorResponse() async throws {
    let fixture = try OTLPTestFixture()
    fixture.stub(signal: "traces", status: 503)
    let exporter = try OTLPTraceExporter(
      configuration: fixture.configuration,
      session: fixture.session
    )
    let span = TraceSpan(name: "GET", context: TraceContext())
    await span.end()
    await #expect(throws: OTLPExportError.rejectedStatus(503)) { try await exporter.export(span) }
    let request = try #require(await fixture.requests().first)
    #expect(request.url?.path == "/v1/traces")
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/x-protobuf")
  }

  @Test("Unfinished spans never reach the transport")
  func rejectsUnfinishedSpan() async throws {
    let fixture = try OTLPTestFixture()
    let exporter = try OTLPTraceExporter(
      configuration: fixture.configuration,
      session: fixture.session
    )
    await #expect(throws: OTLPExportError.unfinishedSpan) {
      try await exporter.export(TraceSpan(name: "GET", context: TraceContext()))
    }
    #expect(await fixture.requests().isEmpty)
  }

  private func hexData(_ value: String) -> Data {
    let bytes = Array(value.utf8)
    return Data(
      stride(from: 0, to: bytes.count, by: 2).compactMap { index in
        String(bytes: bytes[index..<index + 2], encoding: .utf8).flatMap { UInt8($0, radix: 16) }
      }
    )
  }
}
