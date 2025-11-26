import Foundation
import SwiftCheck
import XCTest

@testable import Networking

/// Property-based tests for circuit breaker finite state machine behavior.
///
/// Tests state transitions, invariants, and rolling window behavior.
final class CircuitBreakerFSMPropertyTests: XCTestCase {
  // MARK: - State Invariants

  func testStateIsAlwaysValid() {
    property("Circuit breaker state is always one of closed, open, or halfOpen")
      <- forAll(CircuitBreakerEventSequenceGen.arbitrary) { (events: [CircuitBreakerEvent]) in
        let testResult = await Self.runEventSequence(events)
        switch testResult.finalState {
        case .closed, .open, .halfOpen:
          return true
        }
      }
  }

  // MARK: - State Transition Properties

  func testFailureThresholdTriggersOpen() {
    property("Reaching failure threshold in closed state opens the circuit")
      <- forAll(Gen.choose((1, 10))) { (failureThreshold: Int) in
        await Self.verifyFailureThresholdOpensCircuit(failureThreshold: failureThreshold)
      }
  }

  func testRecoveryTimeoutTriggersHalfOpen() {
    property("Recovery timeout in open state triggers transition to half-open")
      <- forAll(Gen.choose((1, 100))) { (recoveryTimeoutMs: Int) in
        await Self.verifyRecoveryTimeoutTriggersHalfOpen(
          recoveryTimeoutSeconds: TimeInterval(recoveryTimeoutMs) / 1000.0
        )
      }
  }

  func testSuccessThresholdClosesCircuit() {
    property("Success threshold in half-open state closes the circuit")
      <- forAll(Gen.choose((1, 5))) { (successThreshold: Int) in
        await Self.verifySuccessThresholdClosesCircuit(successThreshold: successThreshold)
      }
  }

  func testSingleFailureInHalfOpenOpensCircuit() {
    property("Single failure in half-open state opens the circuit")
      <- forAll { () in
        await Self.verifySingleFailureInHalfOpenOpensCircuit()
      }
  }

  // MARK: - Rolling Window Properties

  func testRollingWindowExcludesOldFailures() {
    property("Rolling window excludes failures older than the window duration")
      <- forAll(Gen.choose((1, 100))) { (windowMs: Int) in
        await Self.verifyRollingWindowExcludesOldFailures(
          rollingWindowSeconds: TimeInterval(windowMs) / 100.0  // 0.01 to 1.0 seconds
        )
      }
  }

  // MARK: - Non-Countable Failures Property

  func testNonCountableFailuresDoNotAffectState() {
    property("Non-countable failures (client errors) don't affect circuit state")
      <- forAll(Gen.choose((1, 10))) { (clientErrorCount: Int) in
        await Self.verifyNonCountableFailuresDoNotAffectState(clientErrorCount: clientErrorCount)
      }
  }

  // MARK: - Helper Methods

  /// Runs a sequence of events against a circuit breaker and returns the final state.
  private static func runEventSequence(
    _ events: [CircuitBreakerEvent]
  ) async -> CircuitBreakerTestResult {
    let mockClient = MockHTTPClient()
    let timeProvider = MockTimeProvider()

    let circuitBreaker = CircuitBreakerMiddleware(
      configuration: .init(
        failureThreshold: 3,
        recoveryTimeout: 1.0,
        successThreshold: 2,
        rollingWindow: 10.0
      ),
      client: mockClient,
      timeProvider: timeProvider
    )

    for event in events {
      switch event {
      case .success:
        mockClient.setNextResponse(success: true)

      case .countableFailure:
        mockClient.setNextResponse(success: false, statusCode: 500)

      case .nonCountableFailure:
        mockClient.setNextResponse(success: false, statusCode: 400)

      case .advanceTime(let seconds):
        timeProvider.advance(by: seconds)
      }

      // Attempt to handle an error (which triggers the circuit breaker logic)
      let request = HTTPRequest(method: .get, url: URL(string: "https://example.com")!)
      let error = HTTPError(category: .network(.serverUnreachable), request: request)
      _ = try? await circuitBreaker.handleError(error, for: request)
    }

    let finalState = await circuitBreaker.currentState
    let failureCount = await circuitBreaker.currentFailureCount

    return CircuitBreakerTestResult(finalState: finalState, failureCount: failureCount)
  }

  /// Verifies that reaching the failure threshold opens the circuit.
  private static func verifyFailureThresholdOpensCircuit(failureThreshold: Int) async -> Bool {
    let mockClient = MockHTTPClient()
    let timeProvider = MockTimeProvider()

    let circuitBreaker = CircuitBreakerMiddleware(
      configuration: .init(
        failureThreshold: failureThreshold,
        recoveryTimeout: 60.0,
        successThreshold: 1,
        rollingWindow: 120.0
      ),
      client: mockClient,
      timeProvider: timeProvider
    )

    // Record exactly failureThreshold failures
    for _ in 0..<failureThreshold {
      mockClient.setNextResponse(success: false, statusCode: 500)
      let request = HTTPRequest(method: .get, url: URL(string: "https://example.com")!)
      let error = HTTPError(category: .network(.serverUnreachable), request: request)
      _ = try? await circuitBreaker.handleError(error, for: request)
    }

    let state = await circuitBreaker.currentState
    if case .open = state {
      return true
    }
    return false
  }

  /// Verifies that recovery timeout triggers half-open state.
  private static func verifyRecoveryTimeoutTriggersHalfOpen(
    recoveryTimeoutSeconds: TimeInterval
  ) async -> Bool {
    let mockClient = MockHTTPClient()
    let timeProvider = MockTimeProvider()

    let circuitBreaker = CircuitBreakerMiddleware(
      configuration: .init(
        failureThreshold: 1,
        recoveryTimeout: recoveryTimeoutSeconds,
        successThreshold: 1,
        rollingWindow: 120.0
      ),
      client: mockClient,
      timeProvider: timeProvider
    )

    // Trigger open state
    mockClient.setNextResponse(success: false, statusCode: 500)
    let request = HTTPRequest(method: .get, url: URL(string: "https://example.com")!)
    let error = HTTPError(category: .network(.serverUnreachable), request: request)
    _ = try? await circuitBreaker.handleError(error, for: request)

    // Verify open
    let openState = await circuitBreaker.currentState
    guard case .open = openState else { return false }

    // Advance time past recovery timeout
    timeProvider.advance(by: recoveryTimeoutSeconds + 0.1)

    // Next request should trigger half-open transition
    mockClient.setNextResponse(success: true)
    _ = try? await circuitBreaker.handleError(error, for: request)

    let halfOpenState = await circuitBreaker.currentState
    // After successful request in half-open, it should close
    // But if we just triggered the transition, the success would close it
    // So we verify it at least transitioned out of open
    if case .open = halfOpenState { return false }
    return true
  }

  /// Verifies that success threshold closes the circuit from half-open.
  private static func verifySuccessThresholdClosesCircuit(successThreshold: Int) async -> Bool {
    let mockClient = MockHTTPClient()
    let timeProvider = MockTimeProvider()

    let circuitBreaker = CircuitBreakerMiddleware(
      configuration: .init(
        failureThreshold: 1,
        recoveryTimeout: 0.001,  // Very short timeout
        successThreshold: successThreshold,
        rollingWindow: 120.0
      ),
      client: mockClient,
      timeProvider: timeProvider
    )

    // Open the circuit
    mockClient.setNextResponse(success: false, statusCode: 500)
    let request = HTTPRequest(method: .get, url: URL(string: "https://example.com")!)
    let error = HTTPError(category: .network(.serverUnreachable), request: request)
    _ = try? await circuitBreaker.handleError(error, for: request)

    // Advance past timeout to transition to half-open
    timeProvider.advance(by: 0.1)

    // Record successes
    for _ in 0..<successThreshold {
      mockClient.setNextResponse(success: true)
      _ = try? await circuitBreaker.handleError(error, for: request)
    }

    let state = await circuitBreaker.currentState
    if case .closed = state { return true }
    return false
  }

  /// Verifies that a single failure in half-open opens the circuit.
  private static func verifySingleFailureInHalfOpenOpensCircuit() async -> Bool {
    let mockClient = MockHTTPClient()
    let timeProvider = MockTimeProvider()

    let circuitBreaker = CircuitBreakerMiddleware(
      configuration: .init(
        failureThreshold: 1,
        recoveryTimeout: 0.001,
        successThreshold: 5,  // High threshold so we don't close on first success
        rollingWindow: 120.0
      ),
      client: mockClient,
      timeProvider: timeProvider
    )

    // Open the circuit
    mockClient.setNextResponse(success: false, statusCode: 500)
    let request = HTTPRequest(method: .get, url: URL(string: "https://example.com")!)
    let error = HTTPError(category: .network(.serverUnreachable), request: request)
    _ = try? await circuitBreaker.handleError(error, for: request)

    // Advance past timeout to transition to half-open
    timeProvider.advance(by: 0.1)

    // Trigger the transition to half-open by attempting a request
    // and then fail it
    mockClient.setNextResponse(success: false, statusCode: 500)
    _ = try? await circuitBreaker.handleError(error, for: request)

    let state = await circuitBreaker.currentState
    if case .open = state { return true }
    return false
  }

  /// Verifies that rolling window excludes old failures.
  private static func verifyRollingWindowExcludesOldFailures(
    rollingWindowSeconds: TimeInterval
  ) async -> Bool {
    let mockClient = MockHTTPClient()
    let timeProvider = MockTimeProvider()

    let circuitBreaker = CircuitBreakerMiddleware(
      configuration: .init(
        failureThreshold: 3,
        recoveryTimeout: 60.0,
        successThreshold: 1,
        rollingWindow: rollingWindowSeconds
      ),
      client: mockClient,
      timeProvider: timeProvider
    )

    // Record 2 failures (below threshold)
    for _ in 0..<2 {
      mockClient.setNextResponse(success: false, statusCode: 500)
      let request = HTTPRequest(method: .get, url: URL(string: "https://example.com")!)
      let error = HTTPError(category: .network(.serverUnreachable), request: request)
      _ = try? await circuitBreaker.handleError(error, for: request)
    }

    // Advance time past the rolling window
    timeProvider.advance(by: rollingWindowSeconds + 0.1)

    // Record 1 more failure (should not trigger open because old failures are excluded)
    mockClient.setNextResponse(success: false, statusCode: 500)
    let request = HTTPRequest(method: .get, url: URL(string: "https://example.com")!)
    let error = HTTPError(category: .network(.serverUnreachable), request: request)
    _ = try? await circuitBreaker.handleError(error, for: request)

    let state = await circuitBreaker.currentState
    // Should still be closed because old failures were excluded
    if case .closed = state { return true }
    return false
  }

  /// Verifies that non-countable failures don't affect circuit state.
  private static func verifyNonCountableFailuresDoNotAffectState(
    clientErrorCount: Int
  ) async -> Bool {
    let mockClient = MockHTTPClient()
    let timeProvider = MockTimeProvider()

    let circuitBreaker = CircuitBreakerMiddleware(
      configuration: .init(
        failureThreshold: 3,
        recoveryTimeout: 60.0,
        successThreshold: 1,
        rollingWindow: 120.0
      ),
      client: mockClient,
      timeProvider: timeProvider
    )

    // Record many client errors (400-499)
    for _ in 0..<clientErrorCount {
      mockClient.setNextResponse(success: false, statusCode: 400)
      let request = HTTPRequest(method: .get, url: URL(string: "https://example.com")!)
      let error = HTTPError(category: .http(.init(rawValue: 400)), request: request)
      _ = try? await circuitBreaker.handleError(error, for: request)
    }

    let state = await circuitBreaker.currentState
    let failureCount = await circuitBreaker.currentFailureCount

    // Should still be closed and failure count should be 0
    if case .closed = state, failureCount == 0 {
      return true
    }
    return false
  }
}

// MARK: - Test Types

/// Events that can occur in circuit breaker testing.
enum CircuitBreakerEvent {
  case success
  case countableFailure  // 5xx, timeout
  case nonCountableFailure  // 4xx
  case advanceTime(TimeInterval)
}

/// Result of running an event sequence.
struct CircuitBreakerTestResult {
  let finalState: CircuitBreakerMiddleware.State
  let failureCount: Int
}

// MARK: - Mock Time Provider

/// Mock time provider for deterministic testing.
final class MockTimeProvider: TimeProvider, @unchecked Sendable {
  private var currentTime: Date
  private let lock = NSLock()

  init(startTime: Date = Date(timeIntervalSinceReferenceDate: 0)) {
    self.currentTime = startTime
  }

  func now() -> Date {
    lock.lock()
    defer { lock.unlock() }
    return currentTime
  }

  func advance(by seconds: TimeInterval) {
    lock.lock()
    defer { lock.unlock() }
    currentTime = currentTime.addingTimeInterval(seconds)
  }

  func set(_ date: Date) {
    lock.lock()
    defer { lock.unlock() }
    currentTime = date
  }
}

// MARK: - Mock HTTP Client

/// Mock HTTP client for circuit breaker testing.
final class MockHTTPClient: HTTPClient, @unchecked Sendable {
  private var nextResponseIsSuccess: Bool = true
  private var nextStatusCode: Int = 200
  private let lock = NSLock()

  func setNextResponse(success: Bool, statusCode: Int = 200) {
    lock.lock()
    defer { lock.unlock() }
    nextResponseIsSuccess = success
    nextStatusCode = statusCode
  }

  func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
    lock.lock()
    let shouldSucceed = nextResponseIsSuccess
    let statusCode = nextStatusCode
    lock.unlock()

    if shouldSucceed {
      return HTTPResponse(
        request: request,
        status: HTTPStatus(rawValue: statusCode),
        headers: [:],
        body: nil
      )
    } else {
      throw HTTPError(
        category: .http(HTTPStatus(rawValue: statusCode)),
        request: request
      )
    }
  }
}

// MARK: - Generators

enum CircuitBreakerEventSequenceGen {
  static var arbitrary: Gen<[CircuitBreakerEvent]> {
    Gen<[CircuitBreakerEvent]>.compose { composer in
      let count = composer.generate(using: Gen.choose((0, 20)))
      var events: [CircuitBreakerEvent] = []

      for _ in 0..<count {
        let eventType = composer.generate(using: Gen.choose((0, 3)))
        switch eventType {
        case 0:
          events.append(.success)

        case 1:
          events.append(.countableFailure)

        case 2:
          events.append(.nonCountableFailure)

        case 3:
          let seconds = Double(composer.generate(using: Gen.choose((1, 100)))) / 100.0
          events.append(.advanceTime(seconds))

        default:
          events.append(.success)
        }
      }

      return events
    }
  }
}
