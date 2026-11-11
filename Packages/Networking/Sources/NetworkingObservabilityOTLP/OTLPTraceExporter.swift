import Foundation
import NetworkingObservability
import OpenTelemetryProtocolExporterCommon
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Sends one completed span as OTLP protobuf using the caller's task and cancellation.
///
/// There is no background worker or queue; return means the collector accepted the HTTP export.
public struct OTLPTraceExporter: TraceExporter {
  private let transport: OTLPHTTPTransport
  private let encoding: OTLPEncoding

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

  public func export(_ span: TraceSpan) async throws(OTLPExportError) {
    let snapshot = await span.snapshot()
    let body = try payload(snapshot)
    let response = try await transport.send(body, signal: .traces)
    try validateResponse(response)
  }

  func payload(_ snapshot: TraceSpanSnapshot) throws(OTLPExportError) -> Data {
    let converter = OTLPSpanConverter(encoding: encoding)
    var scope = Opentelemetry_Proto_Trace_V1_ScopeSpans()
    scope.scope.name = "Networking"
    scope.spans = [try converter.convert(snapshot)]
    var resource = Opentelemetry_Proto_Trace_V1_ResourceSpans()
    resource.resource = encoding.resource()
    resource.scopeSpans = [scope]
    var request = Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest()
    request.resourceSpans = [resource]
    do { return try request.serializedData() } catch { throw .invalidPayload }
  }

  private func validateResponse(_ data: Data) throws(OTLPExportError) {
    do {
      let response = try Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceResponse(
        serializedBytes: data
      )
      guard response.partialSuccess.rejectedSpans == 0 else {
        throw OTLPExportError.partialRejection
      }
    } catch let error as OTLPExportError {
      throw error
    } catch { throw .invalidPayload }
  }
}
