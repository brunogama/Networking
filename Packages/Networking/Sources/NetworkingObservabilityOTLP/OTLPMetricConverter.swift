import NetworkingObservability
import Foundation

/// OpenTelemetry metric semantic names for HTTP client metrics.
///
/// These names follow the OpenTelemetry semantic conventions for HTTP client instrumentation.
/// See: https://opentelemetry.io/docs/specs/semconv/http/http-metrics/
public enum MetricSemanticNames {
  /// Counter: Total HTTP requests made
  public static let httpClientRequestTotal = "http.client.request.total"

  /// Histogram: HTTP request duration in seconds
  public static let httpClientDuration = "http.client.request.duration"

  /// Gauge: Active HTTP requests
  public static let httpClientActiveRequests = "http.client.active_requests"

  /// Counter: HTTP request body size in bytes
  public static let httpClientRequestBodySize = "http.client.request.body.size"

  /// Counter: HTTP response body size in bytes
  public static let httpClientResponseBodySize = "http.client.response.body.size"

  /// Gauge: Error rate (percentage)
  public static let httpClientErrorRate = "http.client.error_rate"

  /// Gauge: Throughput (requests per second)
  public static let httpClientThroughput = "http.client.throughput"

  /// Gauge: Cache hit rate (percentage)
  public static let httpClientCacheHitRate = "http.client.cache_hit_rate"

  /// Counter: Retry count
  public static let httpClientRetryCount = "http.client.retry.count"
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
    public let name: String

    /// Human-readable metric description
    public let description: String

    /// Metric unit (e.g., "s" for seconds, "{request}" for counts)
    public let unit: String

    /// Metric type (counter, gauge, histogram)
    public let type: MetricType

    /// Metric value
    public let value: MetricValue

    /// Observation timestamp
    public let timestamp: Date

    /// Resource and metric-specific attributes
    public let attributes: [String: String]

    /// Type of metric (follows OpenTelemetry metric types)
    public enum MetricType: Sendable {
      case counter
      case gauge
      case histogram
    }

    /// Metric value (supports different numeric types and histogram buckets)
    public enum MetricValue: Sendable {
      case int(Int64)
      case double(Double)
      case histogram(sum: Double, count: Int64, buckets: [Double])
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
    var dataPoints: [MetricDataPoint] = []
    let timestamp = metrics.timestamp
    let baseAttrs = resource.toAttributes()

    // Total requests counter
    dataPoints.append(
      MetricDataPoint(
        name: MetricSemanticNames.httpClientRequestTotal,
        description: "Total number of HTTP requests made",
        unit: "{request}",
        type: .counter,
        value: .int(Int64(metrics.totalRequests)),
        timestamp: timestamp,
        attributes: baseAttrs
      ))

    // Duration histogram (using percentiles)
    dataPoints.append(
      MetricDataPoint(
        name: MetricSemanticNames.httpClientDuration,
        description: "Duration of HTTP requests",
        unit: "s",
        type: .histogram,
        value: .histogram(
          sum: metrics.averageResponseTime * Double(metrics.totalRequests),
          count: Int64(metrics.totalRequests),
          buckets: [
            metrics.p50ResponseTime,
            metrics.p95ResponseTime,
            metrics.p99ResponseTime,
          ]
        ),
        timestamp: timestamp,
        attributes: baseAttrs
      ))

    // Active requests gauge
    dataPoints.append(
      MetricDataPoint(
        name: MetricSemanticNames.httpClientActiveRequests,
        description: "Number of active HTTP requests",
        unit: "{request}",
        type: .gauge,
        value: .int(Int64(metrics.activeConnections)),
        timestamp: timestamp,
        attributes: baseAttrs
      ))

    // Error rate gauge
    dataPoints.append(
      MetricDataPoint(
        name: MetricSemanticNames.httpClientErrorRate,
        description: "HTTP client error rate",
        unit: "1",
        type: .gauge,
        value: .double(metrics.errorRate),
        timestamp: timestamp,
        attributes: baseAttrs
      ))

    // Throughput gauge
    dataPoints.append(
      MetricDataPoint(
        name: MetricSemanticNames.httpClientThroughput,
        description: "HTTP client throughput",
        unit: "{request}/s",
        type: .gauge,
        value: .double(metrics.throughput),
        timestamp: timestamp,
        attributes: baseAttrs
      ))

    // Cache hit rate gauge
    dataPoints.append(
      MetricDataPoint(
        name: MetricSemanticNames.httpClientCacheHitRate,
        description: "HTTP client cache hit rate",
        unit: "1",
        type: .gauge,
        value: .double(metrics.cacheHitRate),
        timestamp: timestamp,
        attributes: baseAttrs
      ))

    return dataPoints
  }
}
