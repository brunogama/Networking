import XCTest
import Foundation
@testable import Networking

/// Comprehensive tests for error handling system including recovery strategies and middleware
final class ErrorHandlingTests: XCTestCase {
  // MARK: - Test Infrastructure

  private var mockClient: ErrorTestMockHTTPClient!
  private var testRequest: HTTPRequest!

  override func setUp() {
    super.setUp()
    mockClient = ErrorTestMockHTTPClient()
    testRequest = HTTPRequest(
      method: .get,
      url: URL(string: "https://api.example.com/test")!,
      headers: [:],
      body: nil,
      timeout: 30.0
    )
  }

  override func tearDown() {
    mockClient = nil
    testRequest = nil
    super.tearDown()
  }

  // MARK: - HTTPError Tests

  func testHTTPErrorCreation() {
    let error = HTTPError(
      category: .network(.noConnection),
      request: testRequest
    )

    XCTAssertEqual(error.category, .network(.noConnection))
    XCTAssertEqual(error.request?.url, testRequest.url)
    XCTAssertNil(error.response)
    XCTAssertNil(error.underlyingError)
  }

  func testHTTPErrorFactoryMethods() {
    let networkError = HTTPError.network(.dnsFailure, request: testRequest)
    XCTAssertEqual(networkError.category, .network(.dnsFailure))

    let httpError = HTTPError.http(status: .notFound, request: testRequest)
    if case .http(let status) = httpError.category {
      XCTAssertEqual(status.rawValue, 404)
    } else {
      XCTFail("Expected HTTP error category")
    }

    let timeoutError = HTTPError.timeout(request: testRequest)
    XCTAssertEqual(timeoutError.category, .timeout)

    let cancelledError = HTTPError.cancelled(request: testRequest)
    XCTAssertEqual(cancelledError.category, .cancelled)
  }

  func testErrorSeverityClassification() {
    let lowSeverityError = HTTPError(category: .cancelled, request: testRequest)
    XCTAssertEqual(lowSeverityError.severity, HTTPError.ErrorSeverity.low)

    let mediumSeverityError = HTTPError(
      category: .http(.badRequest),
      request: testRequest
    )
    XCTAssertEqual(mediumSeverityError.severity, HTTPError.ErrorSeverity.medium)

    let highSeverityError = HTTPError(category: .network(.noConnection), request: testRequest)
    XCTAssertEqual(highSeverityError.severity, HTTPError.ErrorSeverity.high)

    let criticalSeverityError = HTTPError(category: .network(.sslError), request: testRequest)
    XCTAssertEqual(criticalSeverityError.severity, HTTPError.ErrorSeverity.critical)
  }

  func testErrorRecoveryCategories() {
    let retryableError = HTTPError(category: .network(.connectionLost), request: testRequest)
    XCTAssertEqual(retryableError.recoveryCategory, HTTPError.RecoveryCategory.retryableWithDelay)

    let userActionError = HTTPError(
      category: .http(.unauthorized),
      request: testRequest
    )
    XCTAssertEqual(userActionError.recoveryCategory, HTTPError.RecoveryCategory.userActionRequired)

    let nonRecoverableError = HTTPError(
      category: .http(.notFound),
      request: testRequest
    )
    XCTAssertEqual(nonRecoverableError.recoveryCategory, HTTPError.RecoveryCategory.nonRecoverable)

    let configurationError = HTTPError(
      category: .configuration("Invalid API key"),
      request: testRequest
    )
    XCTAssertEqual(
      configurationError.recoveryCategory,
      HTTPError.RecoveryCategory.userActionRequired
    )
  }

  func testErrorClientServerClassification() {
    let clientError = HTTPError(category: .http(.badRequest), request: testRequest)
    XCTAssertTrue(clientError.isClientError)
    XCTAssertFalse(clientError.isServerError)

    let serverError = HTTPError(category: .http(.internalServerError), request: testRequest)
    XCTAssertFalse(serverError.isClientError)
    XCTAssertTrue(serverError.isServerError)

    let networkError = HTTPError(category: .network(.serverUnreachable), request: testRequest)
    XCTAssertFalse(networkError.isClientError)
    XCTAssertTrue(networkError.isServerError)
  }

  func testTransientErrorDetection() {
    let transientError = HTTPError(category: .network(.connectionLost), request: testRequest)
    XCTAssertTrue(transientError.isTransientError)

    let nonTransientError = HTTPError(category: .decoding("Invalid JSON"), request: testRequest)
    XCTAssertFalse(nonTransientError.isTransientError)
  }

  func testUserFriendlyDescriptions() {
    let networkError = HTTPError(category: .network(.noConnection), request: testRequest)
    let description = networkError.userFriendlyDescription
    XCTAssertTrue(description.contains("internet connection"))
    XCTAssertTrue(description.lowercased().contains("check"))
  }

  func testRecoverySuggestions() {
    let networkError = HTTPError(category: .network(.noConnection), request: testRequest)
    let suggestions = networkError.recoverySuggestions
    XCTAssertFalse(suggestions.isEmpty)
    XCTAssertTrue(suggestions.contains { $0.contains("internet connection") })

    let authError = HTTPError(category: .http(.unauthorized), request: testRequest)
    let authSuggestions = authError.recoverySuggestions
    XCTAssertTrue(authSuggestions.contains { $0.contains("log in") })
  }

  // MARK: - ActionableErrorInfo Tests

  func testActionableErrorInfoCreation() {
    let error = HTTPError(category: .network(.noConnection), request: testRequest)
    let context = ActionableErrorInfo.ErrorContext(
      attemptNumber: 1,
      networkCondition: .poor,
      deviceState: .normal
    )

    let actionableError = ActionableErrorInfo(error: error, context: context)

    XCTAssertTrue(actionableError.error.category == error.category)
    XCTAssertEqual(actionableError.context.attemptNumber, 1)
    XCTAssertEqual(actionableError.context.networkCondition, .poor)
    XCTAssertFalse(actionableError.recoveryActions.isEmpty)
    XCTAssertNotNil(actionableError.userMessage)
    XCTAssertNotNil(actionableError.technicalSummary)
  }

  func testRecoveryActionGeneration() {
    let noConnectionError = HTTPError(category: .network(.noConnection), request: testRequest)
    let actionableError = ActionableErrorInfo.analyze(noConnectionError)

    XCTAssertFalse(actionableError.recoveryActions.isEmpty)
    XCTAssertTrue(
      actionableError.recoveryActions.contains { action in
        action.title.contains("Connection") || action.title.contains("Internet")
      }
    )
  }

  func testRecoveryActionTypes() {
    let authError = HTTPError(category: .http(.unauthorized), request: testRequest)
    let actionableError = ActionableErrorInfo.analyze(authError)

    let immediateActions = actionableError.recoveryActions.filter { $0.type == .immediate }
    let userInteractionActions = actionableError.recoveryActions.filter {
      $0.type == .userInteraction
    }

    XCTAssertFalse(immediateActions.isEmpty)
    XCTAssertFalse(userInteractionActions.isEmpty)
  }

  func testAutoExecutableActions() {
    let timeoutError = HTTPError(category: .timeout, request: testRequest)
    let actionableError = ActionableErrorInfo.analyze(timeoutError)

    let autoExecutable = actionableError.autoExecutableActions
    XCTAssertFalse(autoExecutable.isEmpty)
    XCTAssertTrue(autoExecutable.allSatisfy(\.canAutoExecute))
  }

  func testImpactLevelDetermination() {
    let minimalError = HTTPError(category: .cancelled, request: testRequest)
    let minimalActionable = ActionableErrorInfo.analyze(minimalError)
    XCTAssertEqual(minimalActionable.impactLevel, .minimal)

    let criticalError = HTTPError(category: .network(.sslError), request: testRequest)
    let criticalActionable = ActionableErrorInfo.analyze(criticalError)
    XCTAssertEqual(criticalActionable.impactLevel, .critical)
  }

  func testConfidenceLevelDetermination() {
    let transientError = HTTPError(category: .network(.connectionLost), request: testRequest)
    let highConfidence = ActionableErrorInfo.analyze(transientError)
    XCTAssertTrue(
      highConfidence.confidenceLevel.rawValue >= ActionableErrorInfo.ConfidenceLevel.high.rawValue
    )

    let complexError = HTTPError(category: .decoding("Unknown format"), request: testRequest)
    let lowerConfidence = ActionableErrorInfo.analyze(complexError)
    XCTAssertTrue(
      lowerConfidence.confidenceLevel.rawValue
        <= ActionableErrorInfo.ConfidenceLevel.medium.rawValue
    )
  }

  func testEstimatedResolutionTime() {
    let quickError = HTTPError(category: .network(.connectionLost), request: testRequest)
    let quickActionable = ActionableErrorInfo.analyze(quickError)
    let quickTime = quickActionable.estimatedResolutionTime
    XCTAssertGreaterThan(quickTime, 0)
    XCTAssertLessThan(quickTime, 3600)  // Less than an hour
  }

  func testContextualActionGeneration() {
    let error = HTTPError(category: .network(.noConnection), request: testRequest)
    let poorNetworkContext = ActionableErrorInfo.ErrorContext(
      attemptNumber: 1,
      networkCondition: .poor
    )

    let actionable = ActionableErrorInfo.analyze(error, context: poorNetworkContext)

    // Should include network-specific actions for poor network conditions
    XCTAssertTrue(
      actionable.recoveryActions.contains { action in
        action.description.lowercased().contains("network")
          || action.description.lowercased().contains("signal")
          || action.description.lowercased().contains("wifi")
      }
    )
  }

  // MARK: - Error Recovery Strategies Tests

  func testAutomaticRetryStrategy() async {
    let strategy = ErrorRecoveryStrategies.AutomaticRetryStrategy(
      maxAttempts: 2,
      baseDelay: 0.1,
      backoffMultiplier: 1.5,
      jitterFactor: 0.1
    )

    let transientError = HTTPError(category: .network(.connectionLost), request: testRequest)
    XCTAssertTrue(strategy.canRecover(from: transientError))

    let nonTransientError = HTTPError(
      category: .http(.notFound),
      request: testRequest
    )
    XCTAssertFalse(strategy.canRecover(from: nonTransientError))

    // Test recovery with mock client that succeeds on second attempt
    mockClient.responses = [
      .failure(transientError),
      .success(
        HTTPResponse(
          request: testRequest,
          status: HTTPStatus(rawValue: 200),
          headers: [:],
          body: Data()
        )
      ),
    ]

    do {
      let response = try await strategy.recover(
        from: transientError,
        request: testRequest,
        using: mockClient
      )
      XCTAssertEqual(response.status.rawValue, 200)
    } catch {
      XCTFail("Strategy should have succeeded: \(error)")
    }
  }

  @MainActor
  func testAuthenticationRefreshStrategy() async {
    var refreshCalled = false
    let strategy = ErrorRecoveryStrategies.AuthenticationRefreshStrategy(
      tokenRefreshHandler: { @MainActor in
        refreshCalled = true
        return "new-token-123"
      }
    )

    let authError = HTTPError(category: .http(.unauthorized), request: testRequest)
    XCTAssertTrue(strategy.canRecover(from: authError))

    let notAuthError = HTTPError(category: .http(.notFound), request: testRequest)
    XCTAssertFalse(strategy.canRecover(from: notAuthError))

    // Mock successful response after token refresh
    mockClient.responses = [
      .success(
        HTTPResponse(
          request: testRequest,
          status: HTTPStatus(rawValue: 200),
          headers: [:],
          body: Data()
        )
      )
    ]

    do {
      let response = try await strategy.recover(
        from: authError,
        request: testRequest,
        using: mockClient
      )
      XCTAssertTrue(refreshCalled)
      XCTAssertEqual(response.status.rawValue, 200)

      // Verify the new token was added to the request
      XCTAssertEqual(mockClient.lastRequest?.headers["Authorization"], "Bearer new-token-123")
    } catch {
      XCTFail("Auth refresh should have succeeded: \(error)")
    }
  }

  func testCircuitBreakerStrategy() async {
    let strategy = ErrorRecoveryStrategies.CircuitBreakerRecoveryStrategy(
      failureThreshold: 2,
      recoveryTimeout: 0.1
    )

    let serverError = HTTPError(category: .http(.internalServerError), request: testRequest)
    XCTAssertTrue(strategy.canRecover(from: serverError))

    // First failure - should still allow requests
    mockClient.responses = [.failure(serverError)]
    do {
      _ = try await strategy.recover(from: serverError, request: testRequest, using: mockClient)
      XCTFail("Should have failed")
    } catch {
      // Expected failure
    }

    // Second failure - should still allow requests
    mockClient.responses = [.failure(serverError)]
    do {
      _ = try await strategy.recover(from: serverError, request: testRequest, using: mockClient)
      XCTFail("Should have failed")
    } catch {
      // Expected failure
    }

    // Third attempt - circuit should now be open
    do {
      _ = try await strategy.recover(from: serverError, request: testRequest, using: mockClient)
      XCTFail("Circuit should be open")
    } catch let error as HTTPError {
      if case .configuration(let message) = error.category {
        XCTAssertTrue(message.contains("Circuit breaker"))
      } else {
        XCTFail("Expected circuit breaker error")
      }
    } catch {
      XCTFail("Expected HTTPError but got: \(error)")
    }
  }

  func testCompositeRecoveryStrategy() async {
    let authStrategy = ErrorRecoveryStrategies.AuthenticationRefreshStrategy(
      tokenRefreshHandler: { "new-token" }
    )
    let retryStrategy = ErrorRecoveryStrategies.AutomaticRetryStrategy(maxAttempts: 1)

    let composite = ErrorRecoveryStrategies.CompositeRecoveryStrategy(
      strategies: [authStrategy, retryStrategy]
    )

    let authError = HTTPError(category: .http(.unauthorized), request: testRequest)
    XCTAssertTrue(composite.canRecover(from: authError))

    let networkError = HTTPError(category: .network(.connectionLost), request: testRequest)
    XCTAssertTrue(composite.canRecover(from: networkError))
  }

  func testCustomRecoveryStrategy() async {
    let customStrategy = ErrorRecoveryStrategies.CustomRecoveryStrategy(
      maxRecoveryAttempts: 1,
      canRecover: { error in
        error.category == .timeout
      },
      recovery: { _, request, client in
        try await client.execute(request)
      }
    )

    let timeoutError = HTTPError(category: .timeout, request: testRequest)
    XCTAssertTrue(customStrategy.canRecover(from: timeoutError))

    let networkError = HTTPError(category: .network(.noConnection), request: testRequest)
    XCTAssertFalse(customStrategy.canRecover(from: networkError))

    mockClient.responses = [
      .success(
        HTTPResponse(
          request: testRequest,
          status: HTTPStatus(rawValue: 200),
          headers: [:],
          body: Data()
        )
      )
    ]

    do {
      let response = try await customStrategy.recover(
        from: timeoutError,
        request: testRequest,
        using: mockClient
      )
      XCTAssertEqual(response.status.rawValue, 200)
    } catch {
      XCTFail("Custom strategy should have succeeded: \(error)")
    }
  }

  // MARK: - Error Middleware Tests

  func testErrorEnrichmentProcessor() async {
    let processor = ErrorMiddleware.ErrorEnrichmentProcessor()
    let error = HTTPError(category: .network(.noConnection), request: testRequest)
    let context = ErrorMiddleware.ErrorContext(attemptNumber: 2)

    let enrichedError = await processor.process(error: error, for: testRequest, context: context)

    // The enrichment processor currently returns the error as-is since HTTPError is immutable
    // In a real implementation, you might return an enriched error type
    XCTAssertEqual(enrichedError.category, error.category)
  }

  func testErrorClassificationProcessor() async {
    let processor = ErrorMiddleware.ErrorClassificationProcessor()
    let error = HTTPError(category: .http(.internalServerError), request: testRequest)
    let context = ErrorMiddleware.ErrorContext()

    let processedError = await processor.process(error: error, for: testRequest, context: context)
    XCTAssertEqual(processedError.category, error.category)
  }

  func testErrorSanitizationProcessor() async {
    let sensitiveRequest = HTTPRequest(
      method: .get,
      url: URL(string: "https://api.example.com/test?access_token=secret123")!,
      headers: ["Authorization": "Bearer token123"],
      body: nil,
      timeout: 30.0
    )

    let processor = ErrorMiddleware.ErrorSanitizationProcessor()
    let error = HTTPError(category: .network(.noConnection), request: sensitiveRequest)
    let context = ErrorMiddleware.ErrorContext()

    let sanitizedError = await processor.process(
      error: error,
      for: sensitiveRequest,
      context: context
    )

    XCTAssertNotNil(sanitizedError.request)
    XCTAssertEqual(sanitizedError.request?.headers["Authorization"], "***REDACTED***")
    XCTAssertTrue(sanitizedError.request?.url.absoluteString.contains("***REDACTED***") ?? false)
  }

  func testErrorPipeline() async {
    let pipeline = ErrorMiddleware.ErrorPipeline(processors: [
      ErrorMiddleware.ErrorEnrichmentProcessor(),
      ErrorMiddleware.ErrorClassificationProcessor(),
      ErrorMiddleware.ErrorSanitizationProcessor(),
    ])

    let error = HTTPError(category: .network(.noConnection), request: testRequest)
    let context = ErrorMiddleware.ErrorContext(attemptNumber: 1)

    let processedError = await pipeline.process(error: error, for: testRequest, context: context)
    XCTAssertEqual(processedError.category, error.category)
  }

  func testStandardErrorPipeline() {
    let pipeline = ErrorMiddleware.ErrorPipeline.standard(httpClient: mockClient)
    XCTAssertNotNil(pipeline)
  }

  func testDevelopmentErrorPipeline() {
    let pipeline = ErrorMiddleware.ErrorPipeline.development(httpClient: mockClient)
    XCTAssertNotNil(pipeline)
  }

  func testProductionErrorPipeline() {
    let retryStrategy = ErrorRecoveryStrategies.AutomaticRetryStrategy()
    let pipeline = ErrorMiddleware.ErrorPipeline.production(
      httpClient: mockClient,
      recoveryStrategy: retryStrategy
    )
    XCTAssertNotNil(pipeline)
  }

  // MARK: - Error Reporting Tests

  func testConsoleErrorReporter() async {
    let reporter = ErrorMiddleware.ConsoleErrorReporter()
    let error = HTTPError(category: .network(.noConnection), request: testRequest)
    let context = ErrorMiddleware.ErrorContext()

    // This test just ensures the reporter doesn't crash
    await reporter.report(error, context: context)
  }

  func testErrorReportingProcessor() async {
    var reportedError: HTTPError?
    var reportedContext: ErrorMiddleware.ErrorContext?

    let mockReporter = MockErrorReporter { error, context in
      reportedError = error
      reportedContext = context
    }

    let processor = ErrorMiddleware.ErrorReportingProcessor(reporter: mockReporter)
    let error = HTTPError(category: .network(.noConnection), request: testRequest)
    let context = ErrorMiddleware.ErrorContext(attemptNumber: 3)

    let processedError = await processor.process(error: error, for: testRequest, context: context)

    XCTAssertEqual(processedError.category, error.category)
    XCTAssertNotNil(reportedError)
    XCTAssertNotNil(reportedContext)
    XCTAssertEqual(reportedContext?.attemptNumber, 3)
  }

  // MARK: - Integration Tests

  func testErrorHandlingIntegration() async {
    let retryStrategy = ErrorRecoveryStrategies.AutomaticRetryStrategy(
      maxAttempts: 2,
      baseDelay: 0.1
    )

    let pipeline = ErrorMiddleware.ErrorPipeline.standard(
      httpClient: mockClient,
      recoveryStrategy: retryStrategy
    )

    let errorMiddleware = ErrorMiddleware.HTTPErrorMiddleware(pipeline: pipeline)
    let error = HTTPError(category: .network(.connectionLost), request: testRequest)

    do {
      _ = try await errorMiddleware.handleError(error, for: testRequest)
      XCTFail("Error middleware should still throw after processing")
    } catch let processedError as HTTPError {
      XCTAssertEqual(processedError.category, error.category)
    } catch {
      XCTFail("Unexpected error type: \(error)")
    }
  }

  // MARK: - Edge Cases and Error Conditions

  func testEdgeCaseEmptyRecoveryActions() {
    let unknownError = HTTPError(category: .configuration("Unknown error"), request: testRequest)
    let actionableError = ActionableErrorInfo.analyze(unknownError)

    // Should still have some universal recovery actions
    XCTAssertFalse(actionableError.recoveryActions.isEmpty)
  }

  func testEdgeCaseHighAttemptNumber() {
    let error = HTTPError(category: .network(.connectionLost), request: testRequest)
    let highAttemptContext = ActionableErrorInfo.ErrorContext(attemptNumber: 10)
    let actionableError = ActionableErrorInfo.analyze(error, context: highAttemptContext)

    // Should have lower confidence after many attempts
    XCTAssertEqual(actionableError.confidenceLevel, .low)

    // Should suggest contacting support
    XCTAssertTrue(
      actionableError.recoveryActions.contains { action in
        action.type == .contactSupport
      }
    )
  }

  func testEdgeCaseNilRequest() {
    let error = HTTPError(category: .network(.noConnection))
    XCTAssertNil(error.request)

    let actionableError = ActionableErrorInfo.analyze(error)
    XCTAssertFalse(actionableError.recoveryActions.isEmpty)
  }

  func testAsyncErrorPropagation() async {
    let strategy = ErrorRecoveryStrategies.AutomaticRetryStrategy(maxAttempts: 1)
    let error = HTTPError(category: .network(.connectionLost), request: testRequest)

    mockClient.responses = [.failure(error)]

    do {
      _ = try await strategy.recover(from: error, request: testRequest, using: mockClient)
      XCTFail("Should have thrown")
    } catch let caughtError as HTTPError {
      XCTAssertEqual(caughtError.category, error.category)
    } catch {
      XCTFail("Unexpected error type: \(error)")
    }
  }

  // MARK: - Performance Tests

  func testErrorAnalysisPerformance() {
    let error = HTTPError(category: .network(.noConnection), request: testRequest)

    measure {
      for _ in 0..<100 {
        _ = ActionableErrorInfo.analyze(error)
      }
    }
  }

  func testRecoveryStrategyPerformance() async {
    let strategy = ErrorRecoveryStrategies.AutomaticRetryStrategy(maxAttempts: 1)
    let error = HTTPError(category: .network(.connectionLost), request: testRequest)

    await measureAsync { [self] in
      self.mockClient.responses = [
        .success(
          HTTPResponse(
            request: self.testRequest,
            status: HTTPStatus(rawValue: 200),
            headers: [:],
            body: Data()
          )
        )
      ]

      do {
        _ = try await strategy.recover(
          from: error,
          request: self.testRequest,
          using: self.mockClient
        )
      } catch {
        // Ignore errors for performance test
      }
    }
  }
}

// MARK: - Test Utilities

/// Mock HTTP client for testing error recovery strategies
private final class ErrorTestMockHTTPClient: HTTPClient, @unchecked Sendable {
  var responses: [Result<HTTPResponse, HTTPError>] = []
  var lastRequest: HTTPRequest?
  private var responseIndex = 0

  func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
    lastRequest = request

    guard responseIndex < responses.count else {
      throw HTTPError(category: .network(.serverUnreachable), request: request)
    }

    let result = responses[responseIndex]
    responseIndex += 1

    switch result {
    case .success(let response):
      return response

    case .failure(let error):
      throw error
    }
  }
}

/// Mock error reporter for testing error reporting functionality
private final class MockErrorReporter: ErrorMiddleware.ErrorReporter, @unchecked Sendable {
  private let reportHandler: (HTTPError, ErrorMiddleware.ErrorContext) -> Void

  init(reportHandler: @escaping (HTTPError, ErrorMiddleware.ErrorContext) -> Void) {
    self.reportHandler = reportHandler
  }

  func report(_ error: HTTPError, context: ErrorMiddleware.ErrorContext) async {
    reportHandler(error, context)
  }
}

// MARK: - Test Extensions

extension ErrorHandlingTests {
  /// Helper to measure async operations
  private func measureAsync(block: @escaping () async throws -> Void) async {
    let iterations = 10
    let startTime = CFAbsoluteTimeGetCurrent()

    for _ in 0..<iterations {
      try? await block()
    }

    let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
    let averageTime = timeElapsed / Double(iterations)

    print("Average execution time: \(averageTime) seconds")
    XCTAssertLessThan(averageTime, 1.0, "Operation should complete within reasonable time")
  }
}
