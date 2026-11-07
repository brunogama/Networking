import Foundation
import NetworkingObservability
import OpenTelemetryProtocolExporterCommon
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Exports real request-duration observations as OTLP cumulative histograms.
///
/// Histogram count represents request count; no synthetic percentiles or background work is used.
public actor OTLPMetricsCollector: MetricsCollector {
  private let transport: OTLPHTTPTransport
  private let encoding: OTLPEncoding
  private var totals: [HTTPRequestMetrics.Outcome: OTLPMetricTotals] = [:]

  public init(
    configuration: OTLPConfiguration,
    session: URLSession = .shared
  )
    throws(OTLPConfigurationError)
  {
    try configuration.validate()
    self.transport = OTLPHTTPTransport(configuration: configuration, session: session)
    self.encoding = OTLPEncoding(configuration: configuration)
  }

  public func record(_ metrics: HTTPRequestMetrics) async throws(OTLPExportError) {
    let response = try await transport.send(payload(metrics), signal: .metrics)
    try validateResponse(response)
  }

  func payload(_ metrics: HTTPRequestMetrics) throws(OTLPExportError) -> Data {
    var scope = Opentelemetry_Proto_Metrics_V1_ScopeMetrics()
    scope.scope.name = "Networking"
    let updated = try OTLPMetricTotals.recording(metrics, previous: totals[metrics.outcome])
    scope.metrics = [
      try OTLPMetricConverter(encoding: encoding).convert(updated, outcome: metrics.outcome)
    ]
    var resource = Opentelemetry_Proto_Metrics_V1_ResourceMetrics()
    resource.resource = encoding.resource()
    resource.scopeMetrics = [scope]
    var request = Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest()
    request.resourceMetrics = [resource]
    do {
      let data = try request.serializedData()
      totals[metrics.outcome] = updated
      return data
    } catch { throw .invalidPayload }
  }

  private func validateResponse(_ data: Data) throws(OTLPExportError) {
    do {
      let response = try Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceResponse(
        serializedBytes: data
      )
      guard response.partialSuccess.rejectedDataPoints == 0 else {
        throw OTLPExportError.partialRejection
      }
    } catch let error as OTLPExportError {
      throw error
    } catch { throw .invalidPayload }
  }
}
