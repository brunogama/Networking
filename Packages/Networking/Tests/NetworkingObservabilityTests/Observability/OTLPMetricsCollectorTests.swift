@testable import NetworkingObservability
import NetworkingRuntime
import NetworkingDSL
import NetworkingObservabilityOTLP
@testable import NetworkingTesting
import Testing

@Suite("OTLP Metrics Collector Tests")
struct OTLPMetricsCollectorTests {
  // MARK: - Test Helpers

  private func createTestPerformanceMetrics()
    -> NetworkObservabilityMiddleware.PerformanceMetrics
  {
    NetworkObservabilityMiddleware.PerformanceMetrics(
      timestamp: Date(),
      totalRequests: 100,
      successfulRequests: 95,
      failedRequests: 5,
      averageResponseTime: 0.250,
      p50ResponseTime: 0.200,
      p95ResponseTime: 0.500,
      p99ResponseTime: 1.000,
      errorRate: 0.05,
      throughput: 10.0,
      activeConnections: 5,
      cacheHitRate: 0.75,
      retryRate: 0.02,
      topErrors: ["timeout": 3, "server_error": 2],
      topSlowEndpoints: [
        NetworkObservabilityMiddleware.PerformanceMetrics.SlowEndpoint(
          endpoint: "/api/slow",
          averageResponseTime: 0.800
        )
      ],
      networkHealth: NetworkObservabilityMiddleware.PerformanceMetrics.NetworkHealth(
        status: .good,
        latencyGrade: .a,
        reliabilityGrade: .b,
        throughputGrade: .a,
        overallGrade: .b
      )
    )
  }

  // MARK: - Initialization Tests

  @Test("Creates collector with valid configuration")
  func initWithValidConfig() async throws {
    let config = OTLPConfiguration(
      endpoint: URL(string: "http://localhost:4318")!,
      resource: OTLPResource(serviceName: "test-service")
    )

    let collector = try OTLPMetricsCollector(configuration: config)
    // Collector created successfully (non-optional actor)

    await collector.shutdown()
  }

  @Test("Throws on invalid configuration")
  func initThrowsOnInvalidConfig() {
    let config = OTLPConfiguration(
      endpoint: URL(string: "ftp://invalid:4318")!
    )

    #expect(throws: OTLPConfigurationError.self) {
      _ = try OTLPMetricsCollector(configuration: config)
    }
  }

  // MARK: - Record Event Tests

  @Test("Records event without throwing")
  func recordEvent() async throws {
    let config = OTLPConfiguration(
      endpoint: URL(string: "http://localhost:4318")!
    )

    let collector = try OTLPMetricsCollector(configuration: config)

    let requestContext = NetworkObservabilityMiddleware.RequestContext(
      from: HTTPRequest(
        method: .get,
        url: URL(string: "https://api.example.com/users")!
      )
    )

    let event = NetworkObservabilityMiddleware.ObservabilityEvent.requestStarted(requestContext)

    // Should not throw
    await collector.recordEvent(event)

    await collector.shutdown()
  }

  // MARK: - Record Performance Metrics Tests

  @Test("Records performance metrics without throwing")
  func recordPerformanceMetrics() async throws {
    let config = OTLPConfiguration(
      endpoint: URL(string: "http://localhost:4318")!
    )

    let collector = try OTLPMetricsCollector(configuration: config)
    let metrics = createTestPerformanceMetrics()

    // Should not throw
    await collector.recordPerformanceMetrics(metrics)

    await collector.shutdown()
  }

  // MARK: - MetricsCollector Protocol Conformance

  @Test("Conforms to MetricsCollector protocol")
  func conformsToProtocol() async throws {
    let config = OTLPConfiguration(
      endpoint: URL(string: "http://localhost:4318")!
    )

    let collector = try OTLPMetricsCollector(configuration: config)

    // Verify protocol conformance via type constraint
    let _: any MetricsCollector = collector

    await collector.shutdown()
  }

  // MARK: - Metric Conversion Tests

  @Test("OTLPMetricConverter produces expected data points")
  func metricConversion() {
    let resource = OTLPResource(
      serviceName: "test-service",
      serviceVersion: "1.0.0"
    )
    let converter = OTLPMetricConverter(resource: resource)

    let metrics = NetworkObservabilityMiddleware.PerformanceMetrics(
      timestamp: Date(),
      totalRequests: 100,
      successfulRequests: 95,
      failedRequests: 5,
      averageResponseTime: 0.250,
      p50ResponseTime: 0.200,
      p95ResponseTime: 0.500,
      p99ResponseTime: 1.000,
      errorRate: 0.05,
      throughput: 10.0,
      activeConnections: 5,
      cacheHitRate: 0.75,
      retryRate: 0.02,
      topErrors: [:],
      topSlowEndpoints: [],
      networkHealth: NetworkObservabilityMiddleware.PerformanceMetrics.NetworkHealth(
        status: .good,
        latencyGrade: .a,
        reliabilityGrade: .a,
        throughputGrade: .a,
        overallGrade: .a
      )
    )

    let dataPoints = converter.convert(metrics)

    // Verify expected metrics are produced
    #expect(dataPoints.count >= 5)

    let metricNames = dataPoints.map { $0.name }
    #expect(metricNames.contains(MetricSemanticNames.httpClientRequestTotal))
    #expect(metricNames.contains(MetricSemanticNames.httpClientErrorRate))
    #expect(metricNames.contains(MetricSemanticNames.httpClientThroughput))
    #expect(metricNames.contains(MetricSemanticNames.httpClientActiveRequests))
    #expect(metricNames.contains(MetricSemanticNames.httpClientCacheHitRate))
  }
}
