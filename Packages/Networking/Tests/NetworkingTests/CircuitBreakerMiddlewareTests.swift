import Foundation
import XCTest

@testable import Networking

/// Comprehensive tests for CircuitBreakerMiddleware fault tolerance patterns
final class CircuitBreakerMiddlewareTests: XCTestCase {
  // MARK: - Test Infrastructure

  private var mockClient: CircuitBreakerTestMockClient!
  private var testRequest: HTTPRequest!

  override func setUp() {
    super.setUp()
    mockClient = CircuitBreakerTestMockClient()
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

  // MARK: - Configuration Tests

  func testDefaultConfiguration() {
    let config = CircuitBreakerMiddleware.Configuration()

    XCTAssertEqual(config.failureThreshold, 5)
    XCTAssertEqual(config.recoveryTimeout, 60.0)
    XCTAssertEqual(config.successThreshold, 3)
    XCTAssertEqual(config.rollingWindow, 120.0)
  }

  func testCustomConfiguration() {
    let config = CircuitBreakerMiddleware.Configuration(
      failureThreshold: 10,
      recoveryTimeout: 30.0,
      successThreshold: 5,
      rollingWindow: 60.0
    )

    XCTAssertEqual(config.failureThreshold, 10)
    XCTAssertEqual(config.recoveryTimeout, 30.0)
    XCTAssertEqual(config.successThreshold, 5)
    XCTAssertEqual(config.rollingWindow, 60.0)
  }

  func testConfigurationWithCustomFailurePredicate() {
    let customPredicate: @Sendable (HTTPError) -> Bool = { error in
      if case .http(let status) = error.category {
        return status.rawValue >= 500
      }
      return false
    }

    let config = CircuitBreakerMiddleware.Configuration(
      shouldCountFailure: customPredicate
    )

    let serverError = HTTPError(
      category: .http(HTTPStatus(rawValue: 500)),
      request: testRequest
    )
    let clientError = HTTPError(
      category: .http(HTTPStatus(rawValue: 400)),
      request: testRequest
    )

    XCTAssertTrue(config.shouldCountFailure(serverError))
    XCTAssertFalse(config.shouldCountFailure(clientError))
  }

  // MARK: - Initial State Tests

  func testInitialStateClosed() async {
    let config = CircuitBreakerMiddleware.Configuration()
    let sut = CircuitBreakerMiddleware(configuration: config, client: mockClient)

    let state = await sut.currentState
    if case .closed = state {
      // Success
    } else {
      XCTFail("Expected closed state, got \(state)")
    }
  }

  func testInitialFailureCountZero() async {
    let config = CircuitBreakerMiddleware.Configuration()
    let sut = CircuitBreakerMiddleware(configuration: config, client: mockClient)

    let failureCount = await sut.currentFailureCount
    XCTAssertEqual(failureCount, 0)
  }

  // MARK: - Default Failure Counting Tests

  func testShouldCountFailureForServerErrors() {
    let serverError = HTTPError(
      category: .http(HTTPStatus(rawValue: 500)),
      request: testRequest
    )

    XCTAssertTrue(CircuitBreakerMiddleware.Configuration.defaultShouldCountFailure(serverError))
  }

  func testShouldCountFailureFor502Error() {
    let error = HTTPError(
      category: .http(.badGateway),
      request: testRequest
    )

    XCTAssertTrue(CircuitBreakerMiddleware.Configuration.defaultShouldCountFailure(error))
  }

  func testShouldCountFailureFor503Error() {
    let error = HTTPError(
      category: .http(.serviceUnavailable),
      request: testRequest
    )

    XCTAssertTrue(CircuitBreakerMiddleware.Configuration.defaultShouldCountFailure(error))
  }

  func testShouldNotCountFailureForClientErrors() {
    let clientError = HTTPError(
      category: .http(HTTPStatus(rawValue: 400)),
      request: testRequest
    )

    XCTAssertFalse(CircuitBreakerMiddleware.Configuration.defaultShouldCountFailure(clientError))
  }

  func testShouldNotCountFailureFor401() {
    let error = HTTPError(
      category: .http(HTTPStatus(rawValue: 401)),
      request: testRequest
    )

    XCTAssertFalse(CircuitBreakerMiddleware.Configuration.defaultShouldCountFailure(error))
  }

  func testShouldNotCountFailureFor404() {
    let error = HTTPError(
      category: .http(HTTPStatus(rawValue: 404)),
      request: testRequest
    )

    XCTAssertFalse(CircuitBreakerMiddleware.Configuration.defaultShouldCountFailure(error))
  }

  func testShouldCountFailureForNetworkServerUnreachable() {
    let error = HTTPError(
      category: .network(.serverUnreachable),
      request: testRequest
    )

    XCTAssertTrue(CircuitBreakerMiddleware.Configuration.defaultShouldCountFailure(error))
  }

  func testShouldCountFailureForNetworkConnectionLost() {
    let error = HTTPError(
      category: .network(.connectionLost),
      request: testRequest
    )

    XCTAssertTrue(CircuitBreakerMiddleware.Configuration.defaultShouldCountFailure(error))
  }

  func testShouldCountFailureForNetworkNoConnection() {
    let error = HTTPError(
      category: .network(.noConnection),
      request: testRequest
    )

    XCTAssertTrue(CircuitBreakerMiddleware.Configuration.defaultShouldCountFailure(error))
  }

  func testShouldCountFailureForTimeout() {
    let timeoutError = HTTPError(category: .timeout, request: testRequest)

    XCTAssertTrue(CircuitBreakerMiddleware.Configuration.defaultShouldCountFailure(timeoutError))
  }

  func testShouldNotCountFailureForCancelled() {
    let cancelledError = HTTPError(category: .cancelled, request: testRequest)

    XCTAssertFalse(CircuitBreakerMiddleware.Configuration.defaultShouldCountFailure(cancelledError))
  }

  // MARK: - State Transition Tests

  func testTransitionToOpenAfterFailureThreshold() async throws {
    let config = CircuitBreakerMiddleware.Configuration(
      failureThreshold: 3,
      rollingWindow: 300.0
    )
    let sut = CircuitBreakerMiddleware(configuration: config, client: mockClient)
    mockClient.shouldFail = true

    // Trigger 3 failures
    for _ in 0..<3 {
      let serverError = HTTPError(
        category: .network(.serverUnreachable),
        request: testRequest
      )
      do {
        _ = try await sut.handleError(serverError, for: testRequest)
      } catch {
        // Expected to throw
      }
    }

    // Circuit should be open
    let state = await sut.currentState
    if case .open = state {
      // Success
    } else {
      XCTFail("Expected open state after \(config.failureThreshold) failures, got \(state)")
    }
  }

  func testResetClearsStateAndCounters() async throws {
    let config = CircuitBreakerMiddleware.Configuration(failureThreshold: 2)
    let sut = CircuitBreakerMiddleware(configuration: config, client: mockClient)
    mockClient.shouldFail = true

    // Trigger failures to open circuit
    for _ in 0..<2 {
      let error = HTTPError(category: .network(.serverUnreachable), request: testRequest)
      do {
        _ = try await sut.handleError(error, for: testRequest)
      } catch {}
    }

    // Reset
    await sut.reset()

    // Verify state is closed
    let state = await sut.currentState
    if case .closed = state {
      // Success
    } else {
      XCTFail("Expected closed state after reset")
    }

    // Verify failure count is zero
    let failureCount = await sut.currentFailureCount
    XCTAssertEqual(failureCount, 0)
  }

  // MARK: - State Type Tests

  func testStateClosedEquality() {
    let state1 = CircuitBreakerMiddleware.State.closed
    let state2 = CircuitBreakerMiddleware.State.closed

    if case .closed = state1, case .closed = state2 {
      // Both are closed
    } else {
      XCTFail("States should both be closed")
    }
  }

  func testStateOpenContainsDate() {
    let now = Date()
    let state = CircuitBreakerMiddleware.State.open(openedAt: now)

    if case .open(let openedAt) = state {
      XCTAssertEqual(openedAt, now)
    } else {
      XCTFail("Expected open state with date")
    }
  }

  func testStateHalfOpen() {
    let state = CircuitBreakerMiddleware.State.halfOpen

    if case .halfOpen = state {
      // Success
    } else {
      XCTFail("Expected half-open state")
    }
  }

  // MARK: - Factory Method Tests

  func testDefaultFactory() {
    let breaker = CircuitBreakerMiddleware.default(client: mockClient)
    XCTAssertNotNil(breaker)
  }

  func testAggressiveFactory() async {
    let breaker = CircuitBreakerMiddleware.aggressive(client: mockClient)
    XCTAssertNotNil(breaker)

    let state = await breaker.currentState
    if case .closed = state {
      // Success - starts closed
    } else {
      XCTFail("Expected closed initial state")
    }
  }

  func testLenientFactory() async {
    let breaker = CircuitBreakerMiddleware.lenient(client: mockClient)
    XCTAssertNotNil(breaker)

    let state = await breaker.currentState
    if case .closed = state {
      // Success - starts closed
    } else {
      XCTFail("Expected closed initial state")
    }
  }

  // MARK: - CircuitBreakerError Tests

  func testCircuitBreakerErrorDescription() {
    let error = CircuitBreakerError.circuitOpen

    XCTAssertNotNil(error.errorDescription)
    XCTAssertTrue(error.errorDescription?.contains("Circuit breaker is open") ?? false)
  }

  func testCircuitBreakerErrorConformsToError() {
    let error: Error = CircuitBreakerError.circuitOpen
    XCTAssertNotNil(error)
  }
}

// MARK: - Test Mock HTTP Client

private final class CircuitBreakerTestMockClient: HTTPClient, @unchecked Sendable {
  var shouldFail = false
  var failureError: HTTPError?
  var successResponse: HTTPResponse?

  func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
    if shouldFail {
      throw failureError
        ?? HTTPError(
          category: .network(.serverUnreachable),
          request: request
        )
    }
    return successResponse
      ?? HTTPResponse(
        request: request,
        status: .ok,
        headers: [:],
        body: nil
      )
  }
}
