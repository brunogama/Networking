// swiftlint:disable file_length
import Foundation
import XCTest

@testable import NetworkingObservability
import NetworkingRuntime
import NetworkingDSL
@testable import NetworkingTesting

// swiftlint:disable type_body_length
/// Comprehensive tests for RequestTimingMiddleware metrics collection
final class RequestTimingMiddlewareTests: XCTestCase {
  // MARK: - Test Infrastructure

  private var mockCollector: TimingTestMockCollector!
  private var testRequest: HTTPRequest!

  override func setUp() {
    super.setUp()
    mockCollector = TimingTestMockCollector()
    testRequest = HTTPRequest(
      method: .get,
      url: URL(string: "https://api.example.com/test")!,
      headers: [:],
      body: nil,
      timeout: 30.0
    )
  }

  override func tearDown() {
    mockCollector = nil
    testRequest = nil
    super.tearDown()
  }

  // MARK: - RequestMetrics Tests

  func testRequestMetricsDurationCalculation() {
    let startTime = Date()
    let endTime = startTime.addingTimeInterval(0.5)

    let metrics = RequestTimingMiddleware.RequestMetrics(
      requestId: HTTPRequestID(),
      request: testRequest,
      startTime: startTime,
      endTime: endTime,
      isSuccess: true
    )

    XCTAssertEqual(metrics.duration.rawValue, 0.5, accuracy: 0.001)
  }

  func testRequestMetricsRequestBodySize() {
    let bodyData = Data("test body content".utf8)
    let requestWithBody = HTTPRequest(
      method: .post,
      url: URL(string: "https://api.example.com/test")!,
      headers: [:],
      body: bodyData,
      timeout: 30.0
    )

    let metrics = RequestTimingMiddleware.RequestMetrics(
      requestId: HTTPRequestID(),
      request: requestWithBody,
      startTime: Date(),
      endTime: Date(),
      isSuccess: true
    )

    XCTAssertEqual(metrics.requestBodySize.rawValue, bodyData.count)
  }

  func testRequestMetricsWithNilBody() {
    let metrics = RequestTimingMiddleware.RequestMetrics(
      requestId: HTTPRequestID(),
      request: testRequest,
      startTime: Date(),
      endTime: Date(),
      isSuccess: true
    )

    XCTAssertEqual(metrics.requestBodySize.rawValue, 0)
  }

  func testRequestMetricsSuccessWithStatusCode() {
    let metrics = RequestTimingMiddleware.RequestMetrics(
      requestId: HTTPRequestID(),
      request: testRequest,
      startTime: Date(),
      endTime: Date(),
      responseBodySize: ResponseSize(1024),
      statusCode: HTTPStatusCode(200),
      isSuccess: true
    )

    XCTAssertTrue(metrics.isSuccess.rawValue)
    XCTAssertEqual(metrics.statusCode, HTTPStatusCode(200))
    XCTAssertEqual(metrics.responseBodySize, ResponseSize(1024))
    XCTAssertNil(metrics.errorCategory)
  }

  func testRequestMetricsFailureWithErrorCategory() {
    let metrics = RequestTimingMiddleware.RequestMetrics(
      requestId: HTTPRequestID(),
      request: testRequest,
      startTime: Date(),
      endTime: Date(),
      isSuccess: false,
      errorCategory: .timeout
    )

    XCTAssertFalse(metrics.isSuccess.rawValue)
    XCTAssertNil(metrics.statusCode)
    XCTAssertNotNil(metrics.errorCategory)
  }

  func testRequestMetricsWithMetadata() {
    let metadata = ["key1": "value1", "key2": "value2"]

    let metrics = RequestTimingMiddleware.RequestMetrics(
      requestId: UUID(),
      request: testRequest,
      startTime: Date(),
      endTime: Date(),
      isSuccess: true,
      metadata: metadata
    )

    XCTAssertEqual(metrics.metadata[TimingMetadataKey("key1")]?.rawValue, "value1")
    XCTAssertEqual(metrics.metadata[TimingMetadataKey("key2")]?.rawValue, "value2")
  }

  // MARK: - Configuration Tests

  func testDefaultConfiguration() {
    let config = RequestTimingMiddleware.Configuration()

    XCTAssertTrue(config.collectDetailedMetrics.rawValue)
    XCTAssertTrue(config.includeBodySizes.rawValue)
    XCTAssertEqual(config.maxConcurrentTimings, 1000)
  }

  func testCustomConfiguration() {
    let config = RequestTimingMiddleware.Configuration(
      collectDetailedMetrics: false,
      includeBodySizes: false,
      maxConcurrentTimings: 500
    )

    XCTAssertFalse(config.collectDetailedMetrics.rawValue)
    XCTAssertFalse(config.includeBodySizes.rawValue)
    XCTAssertEqual(config.maxConcurrentTimings, 500)
  }

  func testConfigurationShouldCollectMetricsPredicate() {
    let config = RequestTimingMiddleware.Configuration(
      shouldCollectMetrics: { request in
        MetricsCollectionDecision(request.method == .get)
      }
    )

    let getRequest = HTTPRequest(
      method: .get,
      url: URL(string: "https://api.example.com/test")!,
      headers: [:],
      body: nil,
      timeout: 30.0
    )

    let postRequest = HTTPRequest(
      method: .post,
      url: URL(string: "https://api.example.com/test")!,
      headers: [:],
      body: nil,
      timeout: 30.0
    )

    XCTAssertTrue(config.shouldCollectMetrics(getRequest).rawValue)
    XCTAssertFalse(config.shouldCollectMetrics(postRequest).rawValue)
  }

  func testConfigurationMetadataGenerator() {
    let config = RequestTimingMiddleware.Configuration(
      metadataGenerator: { request in
        [TimingMetadataKey("method"): TimingMetadataValue(request.method.rawValue.rawValue)]
      }
    )

    let metadata = config.metadataGenerator(testRequest)
    XCTAssertEqual(metadata[TimingMetadataKey("method")]?.rawValue, "GET")
  }

  // MARK: - MemoryMetricsCollector Tests

  func testMemoryMetricsCollectorInitialization() async {
    let collector = MemoryMetricsCollector(maxMetricsCount: 100)

    let metrics = await collector.allMetrics
    XCTAssertTrue(metrics.isEmpty)
  }

  func testMemoryMetricsCollectorRecordsMetrics() async {
    let collector = MemoryMetricsCollector()

    let requestMetrics = RequestTimingMiddleware.RequestMetrics(
      requestId: HTTPRequestID(),
      request: testRequest,
      startTime: Date(),
      endTime: Date(),
      isSuccess: true
    )

    await collector.recordMetrics(requestMetrics)

    let allMetrics = await collector.allMetrics
    XCTAssertEqual(allMetrics.count, 1)
  }

  func testMemoryMetricsCollectorSuccessfulRequests() async {
    let collector = MemoryMetricsCollector()

    let successMetrics = RequestTimingMiddleware.RequestMetrics(
      requestId: HTTPRequestID(),
      request: testRequest,
      startTime: Date(),
      endTime: Date(),
      isSuccess: true
    )

    let failureMetrics = RequestTimingMiddleware.RequestMetrics(
      requestId: HTTPRequestID(),
      request: testRequest,
      startTime: Date(),
      endTime: Date(),
      isSuccess: false
    )

    await collector.recordMetrics(successMetrics)
    await collector.recordMetrics(failureMetrics)

    let successful = await collector.successfulRequests
    XCTAssertEqual(successful.count, 1)
    XCTAssertTrue(successful.first?.isSuccess.rawValue ?? false)
  }

  func testMemoryMetricsCollectorFailedRequests() async {
    let collector = MemoryMetricsCollector()

    let successMetrics = RequestTimingMiddleware.RequestMetrics(
      requestId: HTTPRequestID(),
      request: testRequest,
      startTime: Date(),
      endTime: Date(),
      isSuccess: true
    )

    let failureMetrics = RequestTimingMiddleware.RequestMetrics(
      requestId: HTTPRequestID(),
      request: testRequest,
      startTime: Date(),
      endTime: Date(),
      isSuccess: false
    )

    await collector.recordMetrics(successMetrics)
    await collector.recordMetrics(failureMetrics)

    let failed = await collector.failedRequests
    XCTAssertEqual(failed.count, 1)
    XCTAssertFalse(failed.first?.isSuccess.rawValue ?? true)
  }

  func testMemoryMetricsCollectorAverageResponseTime() async {
    let collector = MemoryMetricsCollector()
    let startTime = Date()

    // Add metrics with known durations
    let metrics1 = RequestTimingMiddleware.RequestMetrics(
      requestId: HTTPRequestID(),
      request: testRequest,
      startTime: startTime,
      endTime: startTime.addingTimeInterval(0.1),
      isSuccess: true
    )

    let metrics2 = RequestTimingMiddleware.RequestMetrics(
      requestId: HTTPRequestID(),
      request: testRequest,
      startTime: startTime,
      endTime: startTime.addingTimeInterval(0.3),
      isSuccess: true
    )

    await collector.recordMetrics(metrics1)
    await collector.recordMetrics(metrics2)

    let average = await collector.averageResponseTime
    XCTAssertEqual(average.rawValue, 0.2, accuracy: 0.01)
  }

  func testMemoryMetricsCollectorAverageResponseTimeEmpty() async {
    let collector = MemoryMetricsCollector()

    let average = await collector.averageResponseTime
    XCTAssertEqual(average.rawValue, 0)
  }

  func testMemoryMetricsCollectorP95ResponseTime() async {
    let collector = MemoryMetricsCollector()
    let startTime = Date()

    // Add 100 metrics with increasing durations
    for i in 1...100 {
      let metrics = RequestTimingMiddleware.RequestMetrics(
        requestId: HTTPRequestID(),
        request: testRequest,
        startTime: startTime,
        endTime: startTime.addingTimeInterval(Double(i) * 0.01),
        isSuccess: true
      )
      await collector.recordMetrics(metrics)
    }

    let p95 = await collector.p95ResponseTime
    // P95 should be around 0.95-0.96 seconds
    XCTAssertGreaterThan(p95.rawValue, 0.9)
    XCTAssertLessThanOrEqual(p95.rawValue, 1.0)
  }

  func testMemoryMetricsCollectorP95ResponseTimeEmpty() async {
    let collector = MemoryMetricsCollector()

    let p95 = await collector.p95ResponseTime
    XCTAssertEqual(p95.rawValue, 0)
  }

  func testMemoryMetricsCollectorMaxMetricsLimit() async {
    let collector = MemoryMetricsCollector(maxMetricsCount: 5)

    // Add more metrics than the limit
    for _ in 0..<10 {
      let metrics = RequestTimingMiddleware.RequestMetrics(
        requestId: HTTPRequestID(),
        request: testRequest,
        startTime: Date(),
        endTime: Date(),
        isSuccess: true
      )
      await collector.recordMetrics(metrics)
    }

    let allMetrics = await collector.allMetrics
    XCTAssertEqual(allMetrics.count, 5)
  }

  func testMemoryMetricsCollectorClearMetrics() async {
    let collector = MemoryMetricsCollector()

    let metrics = RequestTimingMiddleware.RequestMetrics(
      requestId: HTTPRequestID(),
      request: testRequest,
      startTime: Date(),
      endTime: Date(),
      isSuccess: true
    )
    await collector.recordMetrics(metrics)

    await collector.clearMetrics()

    let allMetrics = await collector.allMetrics
    XCTAssertTrue(allMetrics.isEmpty)
  }

  // MARK: - LoggingMetricsCollector Tests

  func testLoggingMetricsCollectorInitialization() {
    let collector = LoggingMetricsCollector(logLevel: .debug)
    XCTAssertNotNil(collector)
  }

  func testLoggingMetricsCollectorLogLevels() {
    let levels: [LoggingMetricsCollector.LogLevel] = [.debug, .info, .warning, .error]

    for level in levels {
      XCTAssertFalse(level.label.isEmpty.rawValue)
    }

    XCTAssertEqual(LoggingMetricsCollector.LogLevel.debug.label.rawValue, "DEBUG")
    XCTAssertEqual(LoggingMetricsCollector.LogLevel.info.label.rawValue, "INFO")
    XCTAssertEqual(LoggingMetricsCollector.LogLevel.warning.label.rawValue, "WARNING")
    XCTAssertEqual(LoggingMetricsCollector.LogLevel.error.label.rawValue, "ERROR")
  }

  func testLoggingMetricsCollectorDefaultFormatter() {
    let metrics = RequestTimingMiddleware.RequestMetrics(
      requestId: HTTPRequestID(),
      request: testRequest,
      startTime: Date(),
      endTime: Date().addingTimeInterval(0.1),
      responseBodySize: ResponseSize(1024),
      statusCode: HTTPStatusCode(200),
      isSuccess: true
    )

    let formatted = LoggingMetricsCollector.defaultFormatter(metrics)

    XCTAssertTrue(formatted.contains("GET"))
    XCTAssertTrue(formatted.contains("SUCCESS"))
    XCTAssertTrue(formatted.contains("status: 200"))
    XCTAssertTrue(formatted.contains("size: 1024 bytes"))
  }

  func testLoggingMetricsCollectorDefaultFormatterFailure() {
    let metrics = RequestTimingMiddleware.RequestMetrics(
      requestId: HTTPRequestID(),
      request: testRequest,
      startTime: Date(),
      endTime: Date().addingTimeInterval(0.1),
      isSuccess: false,
      errorCategory: .timeout
    )

    let formatted = LoggingMetricsCollector.defaultFormatter(metrics)

    XCTAssertTrue(formatted.contains("FAILED"))
  }

  // MARK: - CompositeMetricsCollector Tests

  func testCompositeMetricsCollectorForwardsToAll() async {
    let collector1 = TimingTestMockCollector()
    let collector2 = TimingTestMockCollector()

    let composite = CompositeMetricsCollector(collectors: [collector1, collector2])

    let metrics = RequestTimingMiddleware.RequestMetrics(
      requestId: HTTPRequestID(),
      request: testRequest,
      startTime: Date(),
      endTime: Date(),
      isSuccess: true
    )

    await composite.recordMetrics(metrics)

    let count1 = await collector1.recordedMetrics.count
    let count2 = await collector2.recordedMetrics.count

    XCTAssertEqual(count1, 1)
    XCTAssertEqual(count2, 1)
  }

  func testCompositeMetricsCollectorEmptyCollectors() async {
    let composite = CompositeMetricsCollector(collectors: [])

    let metrics = RequestTimingMiddleware.RequestMetrics(
      requestId: HTTPRequestID(),
      request: testRequest,
      startTime: Date(),
      endTime: Date(),
      isSuccess: true
    )

    // Should not throw
    await composite.recordMetrics(metrics)
  }

  // MARK: - Factory Method Tests

  func testWithMemoryCollectorFactory() async {
    let (middleware, collector) = RequestTimingMiddleware.withMemoryCollector(maxMetricsCount: 500)

    XCTAssertNotNil(middleware)
    XCTAssertNotNil(collector)

    let metrics = await collector.allMetrics
    XCTAssertTrue(metrics.isEmpty)
  }

  func testWithLoggingFactory() {
    let middleware = RequestTimingMiddleware.withLogging(logLevel: .debug)
    XCTAssertNotNil(middleware)
  }

  func testWithMemoryAndLoggingFactory() async {
    let (middleware, collector) = RequestTimingMiddleware.withMemoryAndLogging(
      maxMetricsCount: 100,
      logLevel: .info
    )

    XCTAssertNotNil(middleware)
    XCTAssertNotNil(collector)

    let metrics = await collector.allMetrics
    XCTAssertTrue(metrics.isEmpty)
  }

  // MARK: - Middleware Integration Tests

  func testMiddlewareInitialization() {
    let config = RequestTimingMiddleware.Configuration()
    let middleware = RequestTimingMiddleware(
      configuration: config,
      metricsCollector: mockCollector
    )

    XCTAssertNotNil(middleware)
  }

  func testMiddlewareActiveTimingCount() async {
    let config = RequestTimingMiddleware.Configuration()
    let middleware = RequestTimingMiddleware(
      configuration: config,
      metricsCollector: mockCollector
    )

    let count = await middleware.activeTimingCount
    XCTAssertEqual(count.rawValue, 0)
  }

  func testMiddlewareClearActiveTimings() async {
    let config = RequestTimingMiddleware.Configuration()
    let middleware = RequestTimingMiddleware(
      configuration: config,
      metricsCollector: mockCollector
    )

    // Start timing
    _ = try? await middleware.modifyRequest(testRequest)

    // Clear
    await middleware.clearActiveTimings()

    let count = await middleware.activeTimingCount
    XCTAssertEqual(count.rawValue, 0)
  }

  func testMiddlewareModifyRequestStartsTiming() async throws {
    let config = RequestTimingMiddleware.Configuration()
    let middleware = RequestTimingMiddleware(
      configuration: config,
      metricsCollector: mockCollector
    )

    _ = try await middleware.modifyRequest(testRequest)

    let count = await middleware.activeTimingCount
    XCTAssertEqual(count.rawValue, 1)
  }

  func testMiddlewareSkipsCollectionWhenPredicateFails() async throws {
    let config = RequestTimingMiddleware.Configuration(
      shouldCollectMetrics: { _ in MetricsCollectionDecision(false) }
    )
    let middleware = RequestTimingMiddleware(
      configuration: config,
      metricsCollector: mockCollector
    )

    _ = try await middleware.modifyRequest(testRequest)

    let count = await middleware.activeTimingCount
    XCTAssertEqual(count.rawValue, 0)
  }
}
// swiftlint:enable type_body_length

// MARK: - Test Mock Metrics Collector

private actor TimingTestMockCollector: RequestTimingMiddleware.MetricsCollector {
  var recordedMetrics: [RequestTimingMiddleware.RequestMetrics] = []

  func recordMetrics(_ metrics: RequestTimingMiddleware.RequestMetrics) async {
    recordedMetrics.append(metrics)
  }
}
// swiftlint:enable file_length
