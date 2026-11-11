import Foundation
import NetworkingObservability
import OpenTelemetryProtocolExporterCommon

struct OTLPSpanConverter {
  let encoding: OTLPEncoding

  func convert(
    _ snapshot: TraceSpanSnapshot
  ) throws(OTLPExportError)
    -> Opentelemetry_Proto_Trace_V1_Span
  {
    guard let endTime = snapshot.endTime else { throw .unfinishedSpan }
    var result = Opentelemetry_Proto_Trace_V1_Span()
    result.traceID = encoding.identifier(snapshot.context.traceId.rawValue)
    result.spanID = encoding.identifier(snapshot.context.spanId.rawValue)
    result.parentSpanID =
      snapshot.context.parentSpanId.map {
        encoding.identifier($0.rawValue)
      } ?? Data()
    result.flags = UInt32(snapshot.context.traceFlags.rawValue)
    result.name = snapshot.name.rawValue
    result.kind = .client
    result.startTimeUnixNano = try encoding.timestamp(snapshot.startTime)
    result.endTimeUnixNano = try encoding.timestamp(endTime)
    result.attributes = encoding.attributes(snapshot.attributes)
    result.status = status(snapshot.status)
    result.events = try snapshot.events.map(event)
    return result
  }

  private func status(_ value: TraceSpan.SpanStatus) -> Opentelemetry_Proto_Trace_V1_Status {
    var result = Opentelemetry_Proto_Trace_V1_Status()
    switch value {
    case .unset: result.code = .unset
    case .ok: result.code = .ok
    case .error(let message):
      result.code = .error
      result.message = message.rawValue
    }
    return result
  }

  private func event(
    _ value: TraceSpan.SpanEvent
  ) throws(OTLPExportError)
    -> Opentelemetry_Proto_Trace_V1_Span.Event
  {
    var result = Opentelemetry_Proto_Trace_V1_Span.Event()
    result.name = value.name.rawValue
    result.timeUnixNano = try encoding.timestamp(value.timestamp)
    result.attributes = encoding.attributes(value.attributes)
    return result
  }
}
