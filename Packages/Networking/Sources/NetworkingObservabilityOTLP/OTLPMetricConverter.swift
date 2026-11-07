import NetworkingObservability
import OpenTelemetryProtocolExporterCommon

struct OTLPMetricConverter {
  let encoding: OTLPEncoding

  func convert(
    _ totals: OTLPMetricTotals,
    outcome: HTTPRequestMetrics.Outcome
  )
    throws(OTLPExportError) -> Opentelemetry_Proto_Metrics_V1_Metric
  {
    var point = Opentelemetry_Proto_Metrics_V1_HistogramDataPoint()
    point.startTimeUnixNano = try encoding.timestamp(totals.startedAt)
    point.timeUnixNano = try encoding.timestamp(totals.timestamp)
    point.count = totals.count
    point.sum = totals.durationSum
    point.bucketCounts = [totals.count]
    point.attributes = encoding.attributes([("outcome", outcome.rawValue)])
    var metric = Opentelemetry_Proto_Metrics_V1_Metric()
    metric.name = "http.client.request.duration"
    metric.unit = "s"
    metric.description_p = "Duration of completed HTTP client requests"
    metric.histogram.aggregationTemporality = .cumulative
    metric.histogram.dataPoints = [point]
    return metric
  }
}
