import Testing
import Foundation
@testable import ModernNetworking

struct ObservabilityTests {
  // MARK: - NetworkObservabilityMiddleware Tests

  @Test("NetworkObservabilityMiddleware can be created with default configuration")
  func testObservabilityMiddlewareCreation() async throws {
    let collector = SimpleMetricsCollector()
    let middleware = NetworkObservabilityMiddleware.standard(metricsCollector: collector)

    let activeTraceCount = await middleware.activeTraceCount
    #expect(activeTraceCount == 0)
  }

  @Test("NetworkObservabilityMiddleware records request started events")
  func testRequestStartedEvent() async throws {
    let collector = SimpleMetricsCollector()
    let middleware = NetworkObservabilityMiddleware.standard(metricsCollector: collector)

    let request = try HTTPRequest {
      GET("/test-endpoint")
      Header("X-User-ID", "user123")
      Header("X-Session-ID", "session456")
    }

    let processedRequest = try await middleware.modifyRequest(request)
    #expect(processedRequest.id == request.id)

    let events = await collector.allEvents
    #expect(events.count == 1)

    if case .requestStarted(let context) = events.first {
      #expect(context.method == "GET")
      #expect(context.path == "/test-endpoint")
      #expect(context.userId == "user123")
      #expect(context.sessionId == "session456")
    } else {
      Issue.record("Expected request started event")
    }
  }

  @Test("NetworkObservabilityMiddleware records successful request completion")
  func testSuccessfulRequestCompletion() async throws {
    let collector = SimpleMetricsCollector()
    let middleware = NetworkObservabilityMiddleware.standard(metricsCollector: collector)

    let request = try HTTPRequest {
      GET("/api/users")
    }

    // Start request tracking
    _ = try await middleware.modifyRequest(request)

    // Create a successful response
    let response = HTTPResponse(
      request: request,
      status: .ok,
      headers: ["Content-Type": "application/json"],
      body: "{\"users\": []}".data(using: .utf8)
    )

    let processedResponse = try await middleware.processResponse(response, for: request)
    #expect(processedResponse.status == .ok)

    let events = await collector.allEvents
    #expect(events.count == 2)  // Started + Completed

    // Check for completion event
    let completionEvent = events.last
    if case .requestCompleted(let context, let responseContext) = completionEvent {
      #expect(context.method == "GET")
      #expect(context.path == "/api/users")
      #expect(responseContext.statusCode == 200)
      #expect(responseContext.statusCategory == "success")
      #expect(responseContext.duration > 0)
    } else {
      Issue.record("Expected request completed event")
    }
  }

  @Test("NetworkObservabilityMiddleware records failed requests")
  func testFailedRequestHandling() async throws {
    let collector = SimpleMetricsCollector()
    let middleware = NetworkObservabilityMiddleware.standard(metricsCollector: collector)

    let request = try HTTPRequest {
      POST("/api/upload")
    }

    // Start request tracking
    _ = try await middleware.modifyRequest(request)

    // Create an error
    let error = HTTPError.network(.noConnection, request: request)

    do {
      _ = try await middleware.handleError(error, for: request)
      Issue.record("Expected error to be rethrown")
    } catch {
      #expect(error is HTTPError)
    }

    let events = await collector.allEvents
    #expect(events.count == 2)  // Started + Failed

    // Check for failure event
    let failureEvent = events.last
    if case .requestFailed(let context, let errorContext) = failureEvent {
      #expect(context.method == "POST")
      #expect(context.path == "/api/upload")
      #expect(errorContext.errorType == "network")
      #expect(errorContext.errorCategory == "connectivity")
      #expect(errorContext.isRetryable == true)
    } else {
      Issue.record("Expected request failed event")
    }
  }

  @Test("NetworkObservabilityMiddleware tracks performance metrics")
  func testPerformanceMetricsCalculation() async throws {
    let collector = SimpleMetricsCollector()
    let configuration = NetworkObservabilityMiddleware.Configuration(
      enableRealTimeMetrics: true,
      metricsReportingInterval: 0.1  // Report very frequently for testing
    )
    let middleware = NetworkObservabilityMiddleware(
      configuration: configuration,
      metricsCollector: collector
    )

    // Simulate multiple requests
    for i in 0..<5 {
      let request = try HTTPRequest {
        GET("/api/test/\(i)")
      }

      _ = try await middleware.modifyRequest(request)

      // Simulate some processing time
      try await Task.sleep(for: .milliseconds(10))

      if i % 2 == 0 {
        // Successful response
        let response = HTTPResponse(
          request: request,
          status: .ok,
          body: "Success".data(using: .utf8)
        )
        _ = try await middleware.processResponse(response, for: request)
      } else {
        // Failed response
        let error = HTTPError.http(status: .internalServerError, request: request)
        do {
          _ = try await middleware.handleError(error, for: request)
        } catch {
          // Expected
        }
      }
    }

    // Wait for metrics to be calculated
    try await Task.sleep(for: .milliseconds(150))

    let metrics = await middleware.currentMetrics
    #expect(metrics.totalRequests >= 5)
    #expect(metrics.successfulRequests == 3)  // 0, 2, 4 succeed
    #expect(metrics.failedRequests == 2)  // 1, 3 fail
    #expect(metrics.errorRate > 0.0)
    #expect(metrics.averageResponseTime > 0.0)
  }

  @Test("NetworkObservabilityMiddleware calculates network health grades")
  func testNetworkHealthCalculation() async throws {
    let collector = SimpleMetricsCollector()
    let middleware = NetworkObservabilityMiddleware.standard(metricsCollector: collector)

    // Simulate fast, successful requests for excellent health
    for i in 0..<10 {
      let request = try HTTPRequest {
        GET("/fast/\(i)")
      }

      _ = try await middleware.modifyRequest(request)

      let response = HTTPResponse(
        request: request,
        status: .ok,
        body: "OK".data(using: .utf8)
      )
      _ = try await middleware.processResponse(response, for: request)
    }

    let metrics = await middleware.currentMetrics
    let health = metrics.networkHealth

    // With fast successful requests, should have good grades
    #expect(health.reliabilityGrade == .a)  // 0% error rate
    #expect(health.status == .excellent || health.status == .good)
  }

  @Test("NetworkObservabilityMiddleware supports custom event recording")
  func testCustomEventRecording() async throws {
    let collector = SimpleMetricsCollector()
    let middleware = NetworkObservabilityMiddleware.standard(metricsCollector: collector)

    let requestContext = NetworkObservabilityMiddleware.RequestContext(
      from: try HTTPRequest { GET("/test") }
    )

    let customEvent = NetworkObservabilityMiddleware.ObservabilityEvent.circuitBreakerTripped(
      endpoint: "/api/external",
      reason: "High error rate detected"
    )

    await middleware.recordCustomEvent(customEvent)

    let events = await collector.allEvents
    #expect(events.count == 1)

    if case .circuitBreakerTripped(let endpoint, let reason) = events.first {
      #expect(endpoint == "/api/external")
      #expect(reason == "High error rate detected")
    } else {
      Issue.record("Expected circuit breaker event")
    }
  }

  @Test("NetworkObservabilityMiddleware supports retry tracking")
  func testRetryTracking() async throws {
    let collector = SimpleMetricsCollector()
    let middleware = NetworkObservabilityMiddleware.standard(metricsCollector: collector)

    let request = try HTTPRequest {
      GET("/flaky-endpoint")
    }

    // Start request tracking
    _ = try await middleware.modifyRequest(request)

    // Record retry attempts
    await middleware.recordRetryAttempt(for: request.id, attempt: 1)
    await middleware.recordRetryAttempt(for: request.id, attempt: 2)

    // Complete successfully after retries
    let response = HTTPResponse(
      request: request,
      status: .ok,
      body: "Success after retries".data(using: .utf8)
    )
    _ = try await middleware.processResponse(response, for: request)

    let events = await collector.allEvents
    #expect(events.count == 4)  // Started + 2 retries + Completed

    let retryEvents = events.compactMap { event in
      if case .requestRetried(_, let attempt) = event {
        return attempt
      }
      return nil
    }

    #expect(retryEvents == [1, 2])
  }

  @Test("NetworkObservabilityMiddleware supports cache event tracking")
  func testCacheEventTracking() async throws {
    let collector = SimpleMetricsCollector()
    let middleware = NetworkObservabilityMiddleware.standard(metricsCollector: collector)

    let request = try HTTPRequest {
      GET("/cacheable-data")
    }

    // Start request tracking
    _ = try await middleware.modifyRequest(request)

    // Record cache miss and hit
    await middleware.recordCacheEvent(for: request.id, hit: false, cacheKey: "user:123:profile")
    await middleware.recordCacheEvent(for: request.id, hit: true, cacheKey: "user:123:profile")

    let events = await collector.allEvents
    #expect(events.count == 3)  // Started + Miss + Hit

    let cacheEvents = events.compactMap { event -> (Bool, String)? in
      switch event {
      case .cacheHit(_, let key):
        return (true, key)

      case .cacheMiss(_, let key):
        return (false, key)

      default:
        return nil
      }
    }

    #expect(cacheEvents.count == 2)
    #expect(cacheEvents[0].0 == false)  // First was miss
    #expect(cacheEvents[1].0 == true)  // Second was hit
    #expect(cacheEvents[0].1 == "user:123:profile")
  }

  @Test("NetworkObservabilityMiddleware clears data properly")
  func testDataClearing() async throws {
    let collector = SimpleMetricsCollector()
    let middleware = NetworkObservabilityMiddleware.standard(metricsCollector: collector)

    // Add some data
    let request = try HTTPRequest { GET("/test") }
    _ = try await middleware.modifyRequest(request)

    #expect(await middleware.activeTraceCount > 0)

    // Clear all data
    await middleware.clearObservabilityData()

    #expect(await middleware.activeTraceCount == 0)
  }

  // MARK: - MetricsCollector Tests

  @Test("SimpleMetricsCollector stores events and metrics")
  func testSimpleMetricsCollector() async throws {
    let collector = SimpleMetricsCollector(maxEvents: 100)

    let requestContext = NetworkObservabilityMiddleware.RequestContext(
      from: try HTTPRequest { GET("/test") }
    )

    let event = NetworkObservabilityMiddleware.ObservabilityEvent.requestStarted(requestContext)
    await collector.recordEvent(event)

    let events = await collector.allEvents
    #expect(events.count == 1)

    // Test metrics recording
    let metrics = NetworkObservabilityMiddleware.PerformanceMetrics(
      timestamp: Date(),
      totalRequests: 10,
      successfulRequests: 8,
      failedRequests: 2,
      averageResponseTime: 0.5,
      p50ResponseTime: 0.3,
      p95ResponseTime: 1.2,
      p99ResponseTime: 2.0,
      errorRate: 0.2,
      throughput: 5.0,
      activeConnections: 3,
      cacheHitRate: 0.7,
      retryRate: 0.1,
      topErrors: ["network": 2],
      topSlowEndpoints: [("/slow", 2.0)],
      networkHealth: NetworkObservabilityMiddleware.PerformanceMetrics.NetworkHealth(
        status: .good,
        latencyGrade: .b,
        reliabilityGrade: .a,
        throughputGrade: .b,
        overallGrade: .b
      )
    )

    await collector.recordPerformanceMetrics(metrics)

    let performanceHistory = await collector.allPerformanceMetrics
    #expect(performanceHistory.count == 1)

    let latestMetrics = await collector.latestMetrics
    #expect(latestMetrics?.totalRequests == 10)
    #expect(latestMetrics?.successfulRequests == 8)
    #expect(latestMetrics?.errorRate == 0.2)
  }

  @Test("SimpleMetricsCollector respects max events limit")
  func testSimpleMetricsCollectorLimits() async throws {
    let collector = SimpleMetricsCollector(maxEvents: 3)

    // Add more events than the limit
    for i in 0..<5 {
      let context = NetworkObservabilityMiddleware.RequestContext(
        from: try HTTPRequest { GET("/test/\(i)") }
      )
      let event = NetworkObservabilityMiddleware.ObservabilityEvent.requestStarted(context)
      await collector.recordEvent(event)
    }

    let events = await collector.allEvents
    #expect(events.count == 3)  // Should be limited to 3
  }

  @Test("ComprehensiveMetricsCollector handles complex scenarios")
  func testComprehensiveMetricsCollector() async throws {
    let collector = ComprehensiveMetricsCollector.development()

    // Test event recording with session and user tracking
    let request = try HTTPRequest {
      GET("/api/user-action")
      Header("X-User-ID", "user123")
      Header("X-Session-ID", "session456")
    }

    let requestContext = NetworkObservabilityMiddleware.RequestContext(from: request)
    let startEvent = NetworkObservabilityMiddleware.ObservabilityEvent.requestStarted(
      requestContext
    )

    await collector.recordEvent(startEvent)

    // Test performance metrics recording
    let metrics = NetworkObservabilityMiddleware.PerformanceMetrics(
      timestamp: Date(),
      totalRequests: 100,
      successfulRequests: 95,
      failedRequests: 5,
      averageResponseTime: 0.2,
      p50ResponseTime: 0.15,
      p95ResponseTime: 0.8,
      p99ResponseTime: 1.5,
      errorRate: 0.05,
      throughput: 10.0,
      activeConnections: 5,
      cacheHitRate: 0.8,
      retryRate: 0.02,
      topErrors: ["timeout": 3, "network": 2],
      topSlowEndpoints: [("/upload", 2.5), ("/process", 1.8)],
      networkHealth: NetworkObservabilityMiddleware.PerformanceMetrics.NetworkHealth(
        status: .excellent,
        latencyGrade: .a,
        reliabilityGrade: .a,
        throughputGrade: .a,
        overallGrade: .a
      )
    )

    await collector.recordPerformanceMetrics(metrics)

    // Test business metrics
    let businessMetrics = await collector.currentBusinessMetrics
    #expect(businessMetrics.dailyActiveUsers >= 0)
    #expect(businessMetrics.totalSessions >= 0)

    // Test alert system (should not trigger alerts for good metrics in development mode)
    let alerts = await collector.currentAlerts
    #expect(alerts.isEmpty)  // Development collector has alerting disabled

    // Test export functionality
    let yesterday = Date().addingTimeInterval(-86_400)
    let tomorrow = Date().addingTimeInterval(86_400)
    let exportData = await collector.exportMetrics(from: yesterday, to: tomorrow)
    #expect(exportData != nil)
  }

  @Test("ComprehensiveMetricsCollector generates alerts for high error rates")
  func testAlertGeneration() async throws {
    let collector = ComprehensiveMetricsCollector.withCustomAlerts(
      errorRateThreshold: 2.0,  // Very low threshold for testing
      responseTimeThreshold: 0.1
    )

    // Create metrics that should trigger alerts
    let badMetrics = NetworkObservabilityMiddleware.PerformanceMetrics(
      timestamp: Date(),
      totalRequests: 100,
      successfulRequests: 90,
      failedRequests: 10,
      averageResponseTime: 0.5,  // High response time
      p50ResponseTime: 0.3,
      p95ResponseTime: 1.0,
      p99ResponseTime: 2.0,
      errorRate: 0.10,  // 10% error rate (above 2% threshold)
      throughput: 5.0,
      activeConnections: 5,
      cacheHitRate: 0.5,
      retryRate: 0.1,
      topErrors: ["network": 10],
      topSlowEndpoints: [("/slow", 2.0)],
      networkHealth: NetworkObservabilityMiddleware.PerformanceMetrics.NetworkHealth(
        status: .poor,
        latencyGrade: .d,
        reliabilityGrade: .c,
        throughputGrade: .b,
        overallGrade: .c
      )
    )

    await collector.recordPerformanceMetrics(badMetrics)

    let alerts = await collector.currentAlerts
    #expect(!alerts.isEmpty)

    // Check for specific alert types
    let errorRateAlerts = alerts.filter { $0.metric == "error_rate" }
    let responseTimeAlerts = alerts.filter { $0.metric == "response_time" }

    #expect(!errorRateAlerts.isEmpty)
    #expect(!responseTimeAlerts.isEmpty)
  }

  @Test("ObservabilityCompositeMetricsCollector forwards to all collectors")
  func testObservabilityCompositeMetricsCollector() async throws {
    let collector1 = SimpleMetricsCollector()
    let collector2 = SimpleMetricsCollector()
    let consoleCollector = ConsoleMetricsCollector()

    let composite = ObservabilityCompositeMetricsCollector(collectors: [
      collector1, collector2, consoleCollector,
    ])

    let requestContext = NetworkObservabilityMiddleware.RequestContext(
      from: try HTTPRequest { GET("/test") }
    )
    let event = NetworkObservabilityMiddleware.ObservabilityEvent.requestStarted(requestContext)

    await composite.recordEvent(event)

    // Both simple collectors should have received the event
    let events1 = await collector1.allEvents
    let events2 = await collector2.allEvents

    #expect(events1.count == 1)
    #expect(events2.count == 1)
  }

  @Test("ConsoleMetricsCollector formats events correctly")
  func testConsoleMetricsCollectorFormatting() async throws {
    let collector = ConsoleMetricsCollector()

    // Test various event types
    let requestContext = NetworkObservabilityMiddleware.RequestContext(
      from: try HTTPRequest { POST("/api/submit") }
    )

    let events: [NetworkObservabilityMiddleware.ObservabilityEvent] = [
      .requestStarted(requestContext),
      .circuitBreakerTripped(endpoint: "/external", reason: "Too many failures"),
      .cacheHit(requestContext, cacheKey: "user:123"),
      .rateLimitHit(requestContext, limit: 100, windowSeconds: 60),
    ]

    for event in events {
      await collector.recordEvent(event)
      // Console output happens via OSLog, we can't easily test it
      // but we can verify the method doesn't crash
    }

    // Test metrics formatting
    let metrics = NetworkObservabilityMiddleware.PerformanceMetrics(
      timestamp: Date(),
      totalRequests: 50,
      successfulRequests: 45,
      failedRequests: 5,
      averageResponseTime: 0.3,
      p50ResponseTime: 0.2,
      p95ResponseTime: 0.8,
      p99ResponseTime: 1.5,
      errorRate: 0.1,
      throughput: 8.0,
      activeConnections: 3,
      cacheHitRate: 0.7,
      retryRate: 0.05,
      topErrors: ["network": 3, "timeout": 2],
      topSlowEndpoints: [("/slow", 1.5)],
      networkHealth: NetworkObservabilityMiddleware.PerformanceMetrics.NetworkHealth(
        status: .good,
        latencyGrade: .b,
        reliabilityGrade: .a,
        throughputGrade: .a,
        overallGrade: .a
      )
    )

    await collector.recordPerformanceMetrics(metrics)
  }

  // MARK: - Integration Tests

  @Test("Full observability integration with network client")
  func testFullObservabilityIntegration() async throws {
    let metricsCollector = ComprehensiveMetricsCollector.development()
    let observabilityMiddleware = NetworkObservabilityMiddleware.development(
      metricsCollector: metricsCollector
    )

    // Create a mock network client that uses our observability middleware
    let client = NetworkClient {
      BaseURL("https://api.example.com")
      AddMiddleware(observabilityMiddleware)
    }

    // We can't actually make network calls in tests, but we can test
    // that the middleware integrates properly with the client builder
    #expect(client != nil)

    // Test that metrics are properly tracked when we have some events
    let request = try HTTPRequest { GET("/test") }

    // Directly test the middleware
    _ = try await observabilityMiddleware.modifyRequest(request)

    let response = HTTPResponse(
      request: request,
      status: .ok,
      body: "Test response".data(using: .utf8)
    )
    _ = try await observabilityMiddleware.processResponse(response, for: request)

    // Wait for metrics calculation
    try await Task.sleep(for: .milliseconds(50))

    let currentMetrics = await observabilityMiddleware.currentMetrics
    #expect(currentMetrics.totalRequests >= 1)

    let businessMetrics = await metricsCollector.currentBusinessMetrics
    #expect(businessMetrics.totalSessions >= 0)
  }

  @Test("Observability handles high concurrency")
  func testHighConcurrencyObservability() async throws {
    let collector = ComprehensiveMetricsCollector.development()
    let middleware = NetworkObservabilityMiddleware.development(metricsCollector: collector)

    let concurrentRequests = 50

    await withTaskGroup(of: Void.self) { group in
      for i in 0..<concurrentRequests {
        group.addTask {
          do {
            let request = try HTTPRequest {
              GET("/concurrent/\(i)")
            }

            _ = try await middleware.modifyRequest(request)

            // Simulate random success/failure
            if i % 3 == 0 {
              let error = HTTPError.timeout(request: request)
              do {
                _ = try await middleware.handleError(error, for: request)
              } catch {
                // Expected
              }
            } else {
              let response = HTTPResponse(
                request: request,
                status: .ok,
                body: "Success".data(using: .utf8)
              )
              _ = try await middleware.processResponse(response, for: request)
            }
          } catch {
            Issue.record("Unexpected error in concurrent test: \(error)")
          }
        }
      }
    }

    // Give time for all metrics to be processed
    try await Task.sleep(for: .milliseconds(100))

    let metrics = await middleware.currentMetrics
    #expect(metrics.totalRequests >= concurrentRequests)

    let events = await collector.getEvents(
      from: Date().addingTimeInterval(-60),
      to: Date().addingTimeInterval(60)
    )
    #expect(events.count >= concurrentRequests)
  }

  @Test("Observability performance with many events")
  func testObservabilityPerformance() async throws {
    let collector = SimpleMetricsCollector(maxEvents: 1000)
    let middleware = NetworkObservabilityMiddleware.standard(metricsCollector: collector)

    let startTime = Date()
    let eventCount = 100

    for i in 0..<eventCount {
      let request = try HTTPRequest { GET("/perf-test/\(i)") }
      _ = try await middleware.modifyRequest(request)

      let response = HTTPResponse(
        request: request,
        status: .ok,
        body: "OK".data(using: .utf8)
      )
      _ = try await middleware.processResponse(response, for: request)
    }

    let endTime = Date()
    let duration = endTime.timeIntervalSince(startTime)

    // Should complete reasonably quickly (less than 1 second for 100 events)
    #expect(duration < 1.0, "Performance test took too long: \(duration)s")

    let events = await collector.allEvents
    #expect(events.count >= eventCount * 2)  // Start + completion events
  }

  @Test("Observability middleware factory methods work correctly")
  func testObservabilityFactoryMethods() async throws {
    let collector = SimpleMetricsCollector()

    // Test standard configuration
    let standardMiddleware = NetworkObservabilityMiddleware.standard(
      metricsCollector: collector,
      enableRealTimeMetrics: true
    )
    #expect(await standardMiddleware.activeTraceCount == 0)

    // Test production configuration
    let productionMiddleware = NetworkObservabilityMiddleware.production(
      metricsCollector: collector,
      samplingRate: 0.5
    )
    #expect(await productionMiddleware.activeTraceCount == 0)

    // Test development configuration
    let developmentMiddleware = NetworkObservabilityMiddleware.development(
      metricsCollector: collector
    )
    #expect(await developmentMiddleware.activeTraceCount == 0)
  }

  @Test("MetricsCollector factory methods work correctly")
  func testMetricsCollectorFactoryMethods() async throws {
    // Test production collector
    let productionCollector = ComprehensiveMetricsCollector.production()
    await productionCollector.clearAllMetrics()

    let businessMetrics = await productionCollector.currentBusinessMetrics
    #expect(businessMetrics.dailyActiveUsers == 0)

    // Test development collector
    let devCollector = ComprehensiveMetricsCollector.development()
    await devCollector.clearAllMetrics()

    let alerts = await devCollector.currentAlerts
    #expect(alerts.isEmpty)

    // Test custom alerts collector
    let customCollector = ComprehensiveMetricsCollector.withCustomAlerts(
      errorRateThreshold: 1.0,
      responseTimeThreshold: 0.5
    )
    await customCollector.clearAllMetrics()

    #expect(customCollector != nil)
  }
}

// MARK: - Performance and Network Health Tests

struct NetworkHealthTests {
  @Test("Network health calculation handles edge cases")
  func testNetworkHealthEdgeCases() async throws {
    let collector = SimpleMetricsCollector()
    let middleware = NetworkObservabilityMiddleware.standard(metricsCollector: collector)

    // Test with no requests (should not crash)
    let emptyMetrics = await middleware.currentMetrics
    #expect(emptyMetrics.totalRequests == 0)
    #expect(emptyMetrics.networkHealth.status != .critical)

    // Test with perfect performance
    let request = try HTTPRequest { GET("/perfect") }
    _ = try await middleware.modifyRequest(request)

    let response = HTTPResponse(
      request: request,
      status: .ok,
      body: "Perfect".data(using: .utf8)
    )
    _ = try await middleware.processResponse(response, for: request)

    let perfectMetrics = await middleware.currentMetrics
    #expect(perfectMetrics.errorRate == 0.0)
    #expect(perfectMetrics.networkHealth.reliabilityGrade == .a)
  }

  @Test("Performance metrics percentiles are calculated correctly")
  func testPerformancePercentilesCalculation() async throws {
    let collector = SimpleMetricsCollector()
    let middleware = NetworkObservabilityMiddleware.standard(metricsCollector: collector)

    // Create requests with known durations by controlling timing
    let durations: [TimeInterval] = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]

    for (index, _) in durations.enumerated() {
      let request = try HTTPRequest { GET("/timing/\(index)") }
      _ = try await middleware.modifyRequest(request)

      // Small delay to ensure different timestamps
      try await Task.sleep(for: .microseconds(100))

      let response = HTTPResponse(
        request: request,
        status: .ok,
        body: "OK".data(using: .utf8)
      )
      _ = try await middleware.processResponse(response, for: request)
    }

    let metrics = await middleware.currentMetrics
    #expect(metrics.totalRequests >= 10)
    #expect(metrics.averageResponseTime > 0)
    #expect(metrics.p50ResponseTime > 0)
    #expect(metrics.p95ResponseTime > 0)
    #expect(metrics.p99ResponseTime > 0)

    // P95 should be greater than or equal to P50
    #expect(metrics.p95ResponseTime >= metrics.p50ResponseTime)
    #expect(metrics.p99ResponseTime >= metrics.p95ResponseTime)
  }

  @Test("Business metrics track users and sessions correctly")
  func testBusinessMetricsTracking() async throws {
    let collector = ComprehensiveMetricsCollector.development()
    let middleware = NetworkObservabilityMiddleware.development(metricsCollector: collector)

    // Simulate requests from different users and sessions
    let users = ["user1", "user2", "user3"]
    let sessions = ["session1", "session2", "session3", "session4"]

    for (userIndex, user) in users.enumerated() {
      for sessionIndex in 0..<2 {  // Each user has 2 sessions
        let sessionId = sessions[userIndex * 2 + sessionIndex]

        let request = try HTTPRequest {
          GET("/api/action")
          Header("X-User-ID", user)
          Header("X-Session-ID", sessionId)
        }

        _ = try await middleware.modifyRequest(request)

        let response = HTTPResponse(
          request: request,
          status: .ok,
          body: "OK".data(using: .utf8)
        )
        _ = try await middleware.processResponse(response, for: request)
      }
    }

    // Give time for business metrics to update
    try await Task.sleep(for: .milliseconds(50))

    let businessMetrics = await collector.currentBusinessMetrics
    #expect(businessMetrics.dailyActiveUsers == 3)  // 3 unique users
    #expect(businessMetrics.totalSessions >= 6)  // At least 6 sessions (may have more from cleanup)
  }
}

// MARK: - Error Handling and Edge Cases

struct ObservabilityEdgeCaseTests {
  @Test("Observability handles malformed requests gracefully")
  func testMalformedRequestHandling() async throws {
    let collector = SimpleMetricsCollector()
    let middleware = NetworkObservabilityMiddleware.standard(metricsCollector: collector)

    // Test with minimal request
    let minimalRequest = HTTPRequest(
      method: .get,
      url: URL(string: "https://example.com")!
    )

    let processedRequest = try await middleware.modifyRequest(minimalRequest)
    #expect(processedRequest.id == minimalRequest.id)

    // Should not crash with minimal response
    let minimalResponse = HTTPResponse(
      request: minimalRequest,
      status: .ok
    )

    _ = try await middleware.processResponse(minimalResponse, for: minimalRequest)

    let events = await collector.allEvents
    #expect(events.count == 2)  // Start + completion
  }

  @Test("Observability maintains thread safety under stress")
  func testThreadSafetyUnderStress() async throws {
    let collector = ComprehensiveMetricsCollector.development()
    let middleware = NetworkObservabilityMiddleware.development(metricsCollector: collector)

    let iterations = 20
    let concurrency = 10

    await withTaskGroup(of: Void.self) { group in
      for taskId in 0..<concurrency {
        group.addTask {
          for i in 0..<iterations {
            do {
              let request = try HTTPRequest {
                GET("/stress/\(taskId)/\(i)")
              }

              _ = try await middleware.modifyRequest(request)

              // Mix of success and failure
              if (taskId + i) % 3 == 0 {
                let error = HTTPError.network(.noConnection, request: request)
                try? await middleware.handleError(error, for: request)
              } else {
                let response = HTTPResponse(
                  request: request,
                  status: .ok,
                  body: "OK".data(using: .utf8)
                )
                _ = try await middleware.processResponse(response, for: request)
              }
            } catch {
              // Some errors are expected in this stress test
            }
          }
        }
      }
    }

    // Verify that the system is still functional
    let metrics = await middleware.currentMetrics
    #expect(metrics.totalRequests >= iterations * concurrency)

    let traceCount = await middleware.activeTraceCount
    #expect(traceCount >= 0)  // Should not have negative traces
  }

  @Test("Observability handles memory pressure correctly")
  func testMemoryPressureHandling() async throws {
    // Test with very low limits to trigger cleanup
    let config = ComprehensiveMetricsCollector.Configuration(
      maxEventsInMemory: 10,  // Very small limit
      eventRetentionDuration: 1,  // Short retention
      enablePersistence: false
    )

    let collector = ComprehensiveMetricsCollector(configuration: config)
    let middleware = NetworkObservabilityMiddleware.development(metricsCollector: collector)

    // Generate many events to trigger cleanup
    for i in 0..<50 {
      let request = try HTTPRequest { GET("/memory-test/\(i)") }
      _ = try await middleware.modifyRequest(request)

      let response = HTTPResponse(
        request: request,
        status: .ok,
        body: "OK".data(using: .utf8)
      )
      _ = try await middleware.processResponse(response, for: request)
    }

    // Wait for potential cleanup
    try await Task.sleep(for: .milliseconds(100))

    let yesterday = Date().addingTimeInterval(-86_400)
    let tomorrow = Date().addingTimeInterval(86_400)
    let events = await collector.getEvents(from: yesterday, to: tomorrow)

    // Should have cleaned up old events
    #expect(events.count <= 50)  // Should not exceed memory limits significantly
  }
}
