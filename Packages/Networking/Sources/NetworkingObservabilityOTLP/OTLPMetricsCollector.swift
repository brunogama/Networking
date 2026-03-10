import NetworkingObservability
import Foundation

#if canImport(OSLog)
import OSLog
#endif

private struct OTLPMetricPayload: Encodable {
  let resourceMetrics: [OTLPResourceMetric]
}

private struct OTLPResourceMetric: Encodable {
  let resource: OTLPMetricPayloadResource
  let scopeMetrics: [OTLPScopeMetric]
}

private struct OTLPMetricPayloadResource: Encodable {
  let attributes: [[String: String]]
}

private struct OTLPScopeMetric: Encodable {
  let metrics: [OTLPEncodedMetric]
}

private struct OTLPEncodedMetric: Encodable {
  let name: String
  let description: String
  let unit: String
  let gauge: OTLPMetricGaugeData?
  let sum: OTLPMetricSumData?
}

private struct OTLPMetricGaugeData: Encodable {
  let dataPoints: [OTLPMetricPoint]
}

private struct OTLPMetricSumData: Encodable {
  let dataPoints: [OTLPMetricPoint]
  let isMonotonic: Bool
}

private struct OTLPMetricPoint: Encodable {
  let timeUnixNano: String
  let asDouble: Double?
  let asInt: String?
}

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
    if metricBuffer.count >= configuration.batchSize.rawValue {
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
    if elapsed >= configuration.flushInterval.rawValue && !metricBuffer.isEmpty {
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
    let endpoint = configuration.endpoint.appendingPathComponent("v1/metrics").rawValue

    // Create request
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.setValue("application/x-protobuf", forHTTPHeaderField: "Content-Type")
    request.timeoutInterval = configuration.timeout.rawValue

    // Add auth headers
    for (key, value) in configuration.headers {
      request.setValue(value.rawValue, forHTTPHeaderField: key.rawValue)
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
    let metrics = dataPoints.compactMap(encodeMetric)

    let payload = OTLPMetricPayload(
      resourceMetrics: [
        OTLPResourceMetric(
          resource: OTLPMetricPayloadResource(
            attributes: configuration.resource.toAttributes().map {
              [$0.key.rawValue: $0.value.rawValue]
            }
          ),
          scopeMetrics: [OTLPScopeMetric(metrics: metrics)]
        )
      ]
    )

    let encoder = JSONEncoder()
    return try encoder.encode(payload)
  }

  private func encodeMetric(
    _ dataPoint: OTLPMetricConverter.MetricDataPoint
  ) -> OTLPEncodedMetric? {
    guard let encodedPoint = encodeDataPoint(dataPoint) else {
      return nil
    }

    switch dataPoint.type {
    case .counter:
      return OTLPEncodedMetric(
        name: dataPoint.name.rawValue,
        description: dataPoint.description.rawValue,
        unit: dataPoint.unit.rawValue,
        gauge: nil,
        sum: OTLPMetricSumData(dataPoints: [encodedPoint], isMonotonic: true)
      )

    case .gauge, .histogram:
      return OTLPEncodedMetric(
        name: dataPoint.name.rawValue,
        description: dataPoint.description.rawValue,
        unit: dataPoint.unit.rawValue,
        gauge: OTLPMetricGaugeData(dataPoints: [encodedPoint]),
        sum: nil
      )
    }
  }

  private func encodeDataPoint(
    _ dataPoint: OTLPMetricConverter.MetricDataPoint
  ) -> OTLPMetricPoint? {
    let timestamp = String(Int64(dataPoint.timestamp.timeIntervalSince1970 * 1_000_000_000))

    switch dataPoint.value {
    case .int(let value):
      return OTLPMetricPoint(
        timeUnixNano: timestamp,
        asDouble: nil,
        asInt: String(value.rawValue)
      )

    case .double(let value):
      return OTLPMetricPoint(
        timeUnixNano: timestamp,
        asDouble: value.rawValue,
        asInt: nil
      )

    case .histogram:
      // Histogram handling simplified - would need full OTLP histogram structure.
      return nil
    }
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
