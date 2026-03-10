import NetworkingObservability
import Foundation

#if canImport(OSLog)
  import OSLog
#endif

/// OTLP metrics exporter that conforms to the existing MetricsCollector protocol.
///
/// Buffers metrics and exports them to an OTLP HTTP collector endpoint using the OpenTelemetry Protocol.
///
/// ## Example Usage
///
/// ```swift
/// let config = OTLPConfiguration(
///   endpoint: URL(string: "http://localhost:4318")!,
///   resource: OTLPResource(serviceName: "my-app")
/// )
/// let collector = try OTLPMetricsCollector(configuration: config)
///
/// // Use with NetworkObservabilityMiddleware
/// let middleware = NetworkObservabilityMiddleware(
///   configuration: .standard,
///   metricsCollector: collector
/// )
/// ```
public actor OTLPMetricsCollector: MetricsCollector {
  // MARK: - Properties

  private let configuration: OTLPConfiguration
  private let converter: OTLPMetricConverter
  private var metricBuffer: [OTLPMetricConverter.MetricDataPoint] = []
  private var lastFlush = Date()
  private var flushTask: Task<Void, Never>?
  private var eventCount: Int = 0

  #if canImport(OSLog)
    private let logger = Logger(subsystem: "Networking", category: "OTLPMetricsCollector")
  #endif

  // MARK: - Initialization

  /// Creates an OTLP metrics collector with the specified configuration.
  ///
  /// - Parameter configuration: OTLP configuration including endpoint and resource
  /// - Throws: `OTLPConfigurationError` if configuration is invalid
  public init(configuration: OTLPConfiguration) throws {
    try configuration.validate()

    self.configuration = configuration
    self.converter = OTLPMetricConverter(resource: configuration.resource)

    // Defer task start to avoid actor isolation issues
    Task { await self.startPeriodicFlush() }
  }

  deinit {
    flushTask?.cancel()
  }

  // MARK: - MetricsCollector Protocol

  /// Records an observability event.
  ///
  /// Events are counted and logged but not directly exported as metrics.
  /// For metrics export, use `recordPerformanceMetrics(_:)`.
  ///
  /// - Parameter event: The observability event to record
  public func recordEvent(_ event: NetworkObservabilityMiddleware.ObservabilityEvent) async {
    eventCount += 1

    // Log significant events
    #if canImport(OSLog)
      switch event {
      case .circuitBreakerTripped(let endpoint, let reason):
        logger.warning("Circuit breaker tripped for \(endpoint): \(reason)")

      case .rateLimitHit(_, let limit, _):
        logger.warning("Rate limit hit: \(limit)")

      default:
        break
      }
    #endif
  }

  /// Records performance metrics and buffers them for OTLP export.
  ///
  /// Metrics are converted to OTLP format and buffered. When the buffer reaches
  /// `batchSize` or the flush interval elapses, metrics are exported to the collector.
  ///
  /// - Parameter metrics: Performance metrics snapshot to record
  public func recordPerformanceMetrics(
    _ metrics: NetworkObservabilityMiddleware.PerformanceMetrics
  ) async {
    let dataPoints = converter.convert(metrics)
    metricBuffer.append(contentsOf: dataPoints)

    // Flush if buffer is getting large
    if metricBuffer.count >= configuration.batchSize {
      await flushBuffer()
    }
  }

  // MARK: - Private Methods

  private func startPeriodicFlush() {
    flushTask = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(5))
        await self?.flushIfNeeded()
      }
    }
  }

  private func flushIfNeeded() async {
    let elapsed = Date().timeIntervalSince(lastFlush)
    if elapsed >= configuration.flushInterval && !metricBuffer.isEmpty {
      await flushBuffer()
    }
  }

  private func flushBuffer() async {
    guard !metricBuffer.isEmpty else { return }

    let dataPointsToExport = metricBuffer
    metricBuffer.removeAll()
    lastFlush = Date()

    // Build OTLP metrics payload and export
    await exportToOTLP(dataPointsToExport)
  }

  private func exportToOTLP(_ dataPoints: [OTLPMetricConverter.MetricDataPoint]) async {
    // Build the metrics endpoint URL (OTLP HTTP uses /v1/metrics)
    let endpoint = configuration.endpoint.appendingPathComponent("v1/metrics")

    // Create request
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.setValue("application/x-protobuf", forHTTPHeaderField: "Content-Type")
    request.timeoutInterval = configuration.timeout

    // Add auth headers
    for (key, value) in configuration.headers {
      request.setValue(value, forHTTPHeaderField: key)
    }

    // Build payload
    do {
      let payload = try buildOTLPMetricsPayload(dataPoints)
      request.httpBody = payload

      let (_, response) = try await URLSession.shared.data(for: request)

      if let httpResponse = response as? HTTPURLResponse {
        if (200..<300).contains(httpResponse.statusCode) {
          #if canImport(OSLog)
            logger.debug("Exported \(dataPoints.count) metric data points to OTLP")
          #endif
        } else {
          #if canImport(OSLog)
            logger.warning("OTLP metrics export failed with status \(httpResponse.statusCode)")
          #endif
        }
      }
    } catch {
      #if canImport(OSLog)
        logger.error("Failed to export metrics: \(error.localizedDescription)")
      #endif
    }
  }

  private func buildOTLPMetricsPayload(
    _ dataPoints: [OTLPMetricConverter.MetricDataPoint]
  ) throws -> Data {
    // Build a simplified JSON representation for OTLP HTTP/JSON
    // In production, this would ideally use OpenTelemetry's protobuf encoder,
    // but we use JSON as a pragmatic fallback for maximum compatibility
    struct OTLPMetricPayload: Encodable {
      let resourceMetrics: [ResourceMetric]

      struct ResourceMetric: Encodable {
        let resource: ResourceAttributes
        let scopeMetrics: [ScopeMetric]

        struct ResourceAttributes: Encodable {
          let attributes: [[String: String]]
        }

        struct ScopeMetric: Encodable {
          let metrics: [Metric]

          struct Metric: Encodable {
            let name: String
            let description: String
            let unit: String
            let gauge: GaugeData?
            let sum: SumData?

            struct GaugeData: Encodable {
              let dataPoints: [DataPoint]
            }

            struct SumData: Encodable {
              let dataPoints: [DataPoint]
              let isMonotonic: Bool
            }

            struct DataPoint: Encodable {
              let timeUnixNano: String
              let asDouble: Double?
              let asInt: String?
            }
          }
        }
      }
    }

    // Convert data points to OTLP format
    typealias Metric = OTLPMetricPayload.ResourceMetric.ScopeMetric.Metric
    typealias DataPoint = Metric.DataPoint

    var metrics: [Metric] = []

    for dp in dataPoints {
      let dataPoint: DataPoint

      switch dp.value {
      case .int(let val):
        dataPoint = DataPoint(
          timeUnixNano: String(Int64(dp.timestamp.timeIntervalSince1970 * 1_000_000_000)),
          asDouble: nil,
          asInt: String(val)
        )

      case .double(let val):
        dataPoint = DataPoint(
          timeUnixNano: String(Int64(dp.timestamp.timeIntervalSince1970 * 1_000_000_000)),
          asDouble: val,
          asInt: nil
        )

      case .histogram:
        // Histogram handling simplified - would need full OTLP histogram structure
        continue
      }

      let metric: Metric

      switch dp.type {
      case .counter:
        metric = Metric(
          name: dp.name,
          description: dp.description,
          unit: dp.unit,
          gauge: nil,
          sum: Metric.SumData(dataPoints: [dataPoint], isMonotonic: true)
        )

      case .gauge, .histogram:
        metric = Metric(
          name: dp.name,
          description: dp.description,
          unit: dp.unit,
          gauge: Metric.GaugeData(dataPoints: [dataPoint]),
          sum: nil
        )
      }

      metrics.append(metric)
    }

    let payload = OTLPMetricPayload(
      resourceMetrics: [
        .init(
          resource: .init(
            attributes: configuration.resource.toAttributes().map { ["\($0.key)": $0.value] }
          ),
          scopeMetrics: [.init(metrics: metrics)]
        )
      ]
    )

    let encoder = JSONEncoder()
    return try encoder.encode(payload)
  }

  // MARK: - Public Methods

  /// Forces immediate flush of buffered metrics and shuts down the collector.
  ///
  /// Call this method before app termination to ensure all metrics are exported.
  public func shutdown() async {
    flushTask?.cancel()
    await flushBuffer()
  }
}
