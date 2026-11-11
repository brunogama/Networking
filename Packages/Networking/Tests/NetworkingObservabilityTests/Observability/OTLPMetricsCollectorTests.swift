import Foundation
import NetworkingObservability
import OpenTelemetryProtocolExporterCommon
import Testing
@testable import NetworkingObservabilityOTLP

@Suite("OTLP measured duration export")
struct OTLPMetricsCollectorTests {
  @Test("Duration uses a real histogram observation with count, sum, and outcome")
  func encodesMeasuredDuration() async throws {
    let fixture = try OTLPTestFixture()
    let collector = try OTLPMetricsCollector(
      configuration: fixture.configuration,
      session: fixture.session
    )
    let sample = try HTTPRequestMetrics(
      timestamp: Date(timeIntervalSince1970: 2),
      duration: 0.25,
      outcome: .failure
    )
    let decoded = try Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest(
      serializedBytes: await collector.payload(sample)
    )
    let metric = try #require(decoded.resourceMetrics.first?.scopeMetrics.first?.metrics.first)
    let point = try #require(metric.histogram.dataPoints.first)
    #expect(metric.name == "http.client.request.duration")
    #expect(metric.histogram.aggregationTemporality == .cumulative)
    #expect(point.count == 1)
    #expect(point.sum == 0.25)
    #expect(point.bucketCounts == [1])
    #expect(point.explicitBounds.isEmpty)
    #expect(point.attributes.first?.value.stringValue == "failure")
  }

  @Test("Concurrent request durations accumulate without overlapping delta intervals")
  func cumulativeMeasurements() async throws {
    let fixture = try OTLPTestFixture()
    let collector = try OTLPMetricsCollector(
      configuration: fixture.configuration,
      session: fixture.session
    )
    let first = try HTTPRequestMetrics(
      timestamp: Date(timeIntervalSince1970: 2),
      duration: 0.25,
      outcome: .success
    )
    let second = try HTTPRequestMetrics(
      timestamp: Date(timeIntervalSince1970: 3),
      duration: 1,
      outcome: .success
    )
    _ = try await collector.payload(first)
    let decoded = try Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest(
      serializedBytes: await collector.payload(second)
    )
    let point = try #require(
      decoded.resourceMetrics.first?.scopeMetrics.first?.metrics.first?.histogram.dataPoints.first
    )
    #expect(point.count == 2)
    #expect(point.sum == 1.25)
    #expect(point.startTimeUnixNano == 1_750_000_000)
    #expect(point.timeUnixNano == 3_000_000_000)
  }

  @Test("Metrics delivery reaches the metrics endpoint with protobuf")
  func deliversProtobuf() async throws {
    let fixture = try OTLPTestFixture()
    fixture.stub(signal: "metrics", status: 200)
    let collector = try OTLPMetricsCollector(
      configuration: fixture.configuration,
      session: fixture.session
    )
    try await collector.record(HTTPRequestMetrics(duration: 0.1, outcome: .success))
    let request = try #require(await fixture.requests().first)
    #expect(request.url?.path == "/v1/metrics")
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/x-protobuf")
  }

  @Test("Collector partial rejection is a visible error")
  func surfacesPartialRejection() async throws {
    let fixture = try OTLPTestFixture()
    var response = Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceResponse()
    response.partialSuccess.rejectedDataPoints = 1
    fixture.stub(signal: "metrics", status: 200, body: try response.serializedData())
    let collector = try OTLPMetricsCollector(
      configuration: fixture.configuration,
      session: fixture.session
    )
    let sample = try HTTPRequestMetrics(duration: 0.1, outcome: .success)
    await #expect(throws: OTLPExportError.partialRejection) { try await collector.record(sample) }
  }
}
