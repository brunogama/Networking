// swiftlint:disable file_length
import NetworkingCore
import NetworkingObservability
import Foundation

public enum OTLPMetricNameTag: Sendable {}
public enum OTLPMetricDescriptionTag: Sendable {}
public enum OTLPMetricUnitTag: Sendable {}
public enum OTLPMetricScalarValueTag: Sendable {}

public typealias OTLPMetricName = BoundaryString<OTLPMetricNameTag>
public typealias OTLPMetricDescription = BoundaryString<OTLPMetricDescriptionTag>
public typealias OTLPMetricUnit = BoundaryString<OTLPMetricUnitTag>
public typealias OTLPMetricScalarValue = BoundaryDouble<OTLPMetricScalarValueTag>

/// OpenTelemetry metric semantic names for HTTP client metrics.
///
/// These names follow the OpenTelemetry semantic conventions for HTTP client instrumentation.
/// See: https://opentelemetry.io/docs/specs/semconv/http/http-metrics/
public enum MetricSemanticNames {
  /// Counter: Total HTTP requests made
  public static let httpClientRequestTotal = OTLPMetricName(
    rawValue: "http.client.request.total"
  )

  /// Histogram: HTTP request duration in seconds
  public static let httpClientDuration = OTLPMetricName(rawValue: "http.client.request.duration")

  /// Gauge: Active HTTP requests
  public static let httpClientActiveRequests = OTLPMetricName(
    rawValue: "http.client.active_requests"
  )

  /// Counter: HTTP request body size in bytes
  public static let httpClientRequestBodySize = OTLPMetricName(
    rawValue: "http.client.request.body.size"
  )

  /// Counter: HTTP response body size in bytes
  public static let httpClientResponseBodySize = OTLPMetricName(
    rawValue: "http.client.response.body.size"
  )

  /// Gauge: Error rate (percentage)
  public static let httpClientErrorRate = OTLPMetricName(rawValue: "http.client.error_rate")

  /// Gauge: Throughput (requests per second)
  public static let httpClientThroughput = OTLPMetricName(rawValue: "http.client.throughput")

  /// Gauge: Cache hit rate (percentage)
  public static let httpClientCacheHitRate = OTLPMetricName(rawValue: "http.client.cache_hit_rate")

  /// Counter: Retry count
  public static let httpClientRetryCount = OTLPMetricName(rawValue: "http.client.retry.count")
}

/// Converts PerformanceMetrics to OpenTelemetry metric data points.
///
/// This converter transforms our internal PerformanceMetrics structure into OTLP-compatible
/// metric data points following OpenTelemetry semantic conventions.
///
/// ## Example Usage
///
/// ```swift
/// let resource = OTLPResource(serviceName: "my-app")
/// let converter = OTLPMetricConverter(resource: resource)
///
/// let metrics = NetworkObservabilityMiddleware.PerformanceMetrics(...)
/// let dataPoints = converter.convert(metrics)
/// // dataPoints contains OTLP metric data ready for export
/// ```
public struct OTLPMetricConverter: Sendable {
  private let resource: OTLPResource

  private struct ConversionContext {
    let timestamp: Date
    let attributes: [TraceAttributeKey: TraceAttributeValue]
  }

  private struct MetricDescriptor {
    let name: OTLPMetricName
    let description: OTLPMetricDescription
    let unit: OTLPMetricUnit
    let type: MetricDataPoint.MetricType
  }

  /// Creates a new metric converter with the specified resource attributes.
  ///
  /// - Parameter resource: Resource attributes to attach to all metrics
  public init(resource: OTLPResource) {
    self.resource = resource
  }

  /// Metric data point for OTLP export.
  ///
  /// Represents a single metric observation with type, value, timestamp, and attributes.
  public struct MetricDataPoint: Sendable {
    /// Metric name (following OpenTelemetry semantic conventions)
    public let name: OTLPMetricName

    /// Human-readable metric description
    public let description: OTLPMetricDescription

    /// Metric unit (e.g., "s" for seconds, "{request}" for counts)
    public let unit: OTLPMetricUnit

    /// Metric type (counter, gauge, histogram)
    public let type: MetricType

    /// Metric value
    public let value: MetricValue

    /// Observation timestamp
    public let timestamp: Date

    /// Resource and metric-specific attributes
    public let attributes: [TraceAttributeKey: TraceAttributeValue]

    /// Type of metric (follows OpenTelemetry metric types)
    public enum MetricType: Sendable {
      case counter
      case gauge
      case histogram
    }

    /// Metric value (supports different numeric types and histogram buckets)
    public enum MetricValue: Sendable {
      case int(RequestCount)
      case double(OTLPMetricScalarValue)
      case histogram(
        sum: OTLPMetricScalarValue,
        count: RequestCount,
        buckets: [OTLPMetricScalarValue]
      )
    }
  }

  /// Converts PerformanceMetrics to OTLP metric data points.
  ///
  /// This method extracts all relevant metrics from the PerformanceMetrics structure
  /// and converts them to OTLP-compatible data points with semantic convention names.
  ///
  /// - Parameter metrics: Performance metrics snapshot to convert
  /// - Returns: Array of OTLP metric data points ready for export
  public func convert(
    _ metrics: NetworkObservabilityMiddleware.PerformanceMetrics
  ) -> [MetricDataPoint] {
    let context = ConversionContext(
      timestamp: metrics.timestamp,
      attributes: makeBaseAttributes()
    )

    return makeCountBasedDataPoints(metrics, context: context)
      + makeRateDataPoints(metrics, context: context)
  }

  private func makeBaseAttributes() -> [TraceAttributeKey: TraceAttributeValue] {
    Dictionary(
      uniqueKeysWithValues: resource.toAttributes().map {
        (TraceAttributeKey($0.key.rawValue), TraceAttributeValue($0.value.rawValue))
      }
    )
  }

  private func makeCountBasedDataPoints(
    _ metrics: NetworkObservabilityMiddleware.PerformanceMetrics,
    context: ConversionContext
  ) -> [MetricDataPoint] {
    [
      makeCountDataPoint(
        descriptor: MetricDescriptor(
          name: MetricSemanticNames.httpClientRequestTotal,
          description: "Total number of HTTP requests made",
          unit: "{request}",
          type: .counter
        ),
        value: metrics.totalRequests,
        context: context
      ),
      makeHistogramDataPoint(metrics: metrics, context: context),
      makeCountDataPoint(
        descriptor: MetricDescriptor(
          name: MetricSemanticNames.httpClientActiveRequests,
          description: "Number of active HTTP requests",
          unit: "{request}",
          type: .gauge
        ),
        value: RequestCount(metrics.activeConnections.rawValue),
        context: context
      ),
    ]
  }

  private func makeRateDataPoints(
    _ metrics: NetworkObservabilityMiddleware.PerformanceMetrics,
    context: ConversionContext
  ) -> [MetricDataPoint] {
    [
      makeScalarDataPoint(
        descriptor: MetricDescriptor(
          name: MetricSemanticNames.httpClientErrorRate,
          description: "HTTP client error rate",
          unit: "1",
          type: .gauge
        ),
        value: OTLPMetricScalarValue(metrics.errorRate.rawValue),
        context: context
      ),
      makeScalarDataPoint(
        descriptor: MetricDescriptor(
          name: MetricSemanticNames.httpClientThroughput,
          description: "HTTP client throughput",
          unit: "{request}/s",
          type: .gauge
        ),
        value: OTLPMetricScalarValue(metrics.throughput.rawValue),
        context: context
      ),
      makeScalarDataPoint(
        descriptor: MetricDescriptor(
          name: MetricSemanticNames.httpClientCacheHitRate,
          description: "HTTP client cache hit rate",
          unit: "1",
          type: .gauge
        ),
        value: OTLPMetricScalarValue(metrics.cacheHitRate.rawValue),
        context: context
      ),
    ]
  }

  private func makeCountDataPoint(
    descriptor: MetricDescriptor,
    value: RequestCount,
    context: ConversionContext
  ) -> MetricDataPoint {
    MetricDataPoint(
      name: descriptor.name,
      description: descriptor.description,
      unit: descriptor.unit,
      type: descriptor.type,
      value: .int(value),
      timestamp: context.timestamp,
      attributes: context.attributes
    )
  }

  private func makeScalarDataPoint(
    descriptor: MetricDescriptor,
    value: OTLPMetricScalarValue,
    context: ConversionContext
  ) -> MetricDataPoint {
    MetricDataPoint(
      name: descriptor.name,
      description: descriptor.description,
      unit: descriptor.unit,
      type: descriptor.type,
      value: .double(value),
      timestamp: context.timestamp,
      attributes: context.attributes
    )
  }

  private func makeHistogramDataPoint(
    metrics: NetworkObservabilityMiddleware.PerformanceMetrics,
    context: ConversionContext
  ) -> MetricDataPoint {
    MetricDataPoint(
      name: MetricSemanticNames.httpClientDuration,
      description: "Duration of HTTP requests",
      unit: "s",
      type: .histogram,
      value: .histogram(
        sum: OTLPMetricScalarValue(
          metrics.averageResponseTime.rawValue * Double(metrics.totalRequests.rawValue)
        ),
        count: metrics.totalRequests,
        buckets: [
          OTLPMetricScalarValue(metrics.p50ResponseTime.rawValue),
          OTLPMetricScalarValue(metrics.p95ResponseTime.rawValue),
          OTLPMetricScalarValue(metrics.p99ResponseTime.rawValue),
        ]
      ),
      timestamp: context.timestamp,
      attributes: context.attributes
    )
  }
}
