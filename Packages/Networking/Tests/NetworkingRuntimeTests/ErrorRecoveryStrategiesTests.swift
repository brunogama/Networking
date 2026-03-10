import Foundation
import XCTest

@testable import NetworkingRuntime
import NetworkingDSL
import NetworkingRuntimeDSL
import NetworkingTesting

/// Comprehensive tests for ErrorRecoveryStrategies retry and recovery logic
final class ErrorRecoveryStrategiesTests: XCTestCase {
    // MARK: - Test Infrastructure

    private var mockClient: RecoveryTestMockHTTPClient!
    private var testRequest: HTTPRequest!

    override func setUp() {
        super.setUp()
        mockClient = RecoveryTestMockHTTPClient()
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

    // MARK: - AutomaticRetryStrategy Configuration Tests

    func testAutomaticRetryDefaultConfiguration() {
        let strategy = ErrorRecoveryStrategies.AutomaticRetryStrategy()

        XCTAssertEqual(strategy.maxRecoveryAttempts, 3)
    }

    func testAutomaticRetryCustomConfiguration() {
        let strategy = ErrorRecoveryStrategies.AutomaticRetryStrategy(
            maxAttempts: 5,
            baseDelay: 2.0,
            backoffMultiplier: 3.0,
            jitterFactor: 0.2
        )

        XCTAssertEqual(strategy.maxRecoveryAttempts, 5)
    }

    func testAutomaticRetrySingleAttempt() {
        let strategy = ErrorRecoveryStrategies.AutomaticRetryStrategy(maxAttempts: 1)
        XCTAssertEqual(strategy.maxRecoveryAttempts, 1)
    }

    // MARK: - AutomaticRetryStrategy canRecover Tests

    func testCanRecoverFromTransientNetworkErrors() {
        let strategy = ErrorRecoveryStrategies.AutomaticRetryStrategy()

        let transientErrors: [HTTPError] = [
            HTTPError(category: .network(.serverUnreachable), request: testRequest),
            HTTPError(category: .network(.connectionLost), request: testRequest),
            HTTPError(category: .network(.noConnection), request: testRequest),
            HTTPError(category: .timeout, request: testRequest),
        ]

        for error in transientErrors {
            XCTAssertTrue(
                strategy.canRecover(from: error),
                "Should recover from \(error.category)"
            )
        }
    }

    func testCanRecoverFrom503ServiceUnavailable() {
        let strategy = ErrorRecoveryStrategies.AutomaticRetryStrategy()

        let error = HTTPError(
            category: .http(.serviceUnavailable),
            request: testRequest
        )

        XCTAssertTrue(strategy.canRecover(from: error))
    }

    func testCanRecoverFrom502BadGateway() {
        let strategy = ErrorRecoveryStrategies.AutomaticRetryStrategy()

        let error = HTTPError(
            category: .http(.badGateway),
            request: testRequest
        )

        XCTAssertTrue(strategy.canRecover(from: error))
    }

    func testCannotRecoverFrom504GatewayTimeout() {
        let strategy = ErrorRecoveryStrategies.AutomaticRetryStrategy()

        // Per HTTPError.recoveryCategory, 504 returns .nonRecoverable
        let error = HTTPError(
            category: .http(.gatewayTimeout),
            request: testRequest
        )

        XCTAssertFalse(strategy.canRecover(from: error))
    }

    func testCannotRecoverFromPermanentErrors() {
        let strategy = ErrorRecoveryStrategies.AutomaticRetryStrategy()

        // Per HTTPError.recoveryCategory, these errors return .userActionRequired or .nonRecoverable
        // 401, 403 -> .userActionRequired, 404 -> .nonRecoverable
        // 504 -> .nonRecoverable
        let permanentErrors: [HTTPError] = [
            HTTPError(category: .http(.unauthorized), request: testRequest),
            HTTPError(category: .http(.forbidden), request: testRequest),
            HTTPError(category: .http(.notFound), request: testRequest),
            HTTPError(category: .http(.gatewayTimeout), request: testRequest),
        ]

        for error in permanentErrors {
            XCTAssertFalse(
                strategy.canRecover(from: error),
                "Should not recover from \(error.category)"
            )
        }
    }

    func testCannotRecoverFromCancelledError() {
        let strategy = ErrorRecoveryStrategies.AutomaticRetryStrategy()
        let error = HTTPError(category: .cancelled, request: testRequest)

        XCTAssertFalse(strategy.canRecover(from: error))
    }

    // MARK: - AuthenticationRefreshStrategy Tests

    func testAuthenticationRefreshStrategyInitialization() {
        let strategy = ErrorRecoveryStrategies.AuthenticationRefreshStrategy(
            headerName: "Authorization",
            tokenPrefix: "Bearer ",
            tokenRefreshHandler: { "newToken" }
        )

        XCTAssertEqual(strategy.maxRecoveryAttempts, 1)
    }

    func testAuthenticationRefreshCanRecoverFrom401() {
        let strategy = ErrorRecoveryStrategies.AuthenticationRefreshStrategy(
            tokenRefreshHandler: { "newToken" }
        )

        let error = HTTPError(
            category: .http(.unauthorized),
            request: testRequest
        )

        XCTAssertTrue(strategy.canRecover(from: error))
    }

    func testAuthenticationRefreshCannotRecoverFrom403() {
        let strategy = ErrorRecoveryStrategies.AuthenticationRefreshStrategy(
            tokenRefreshHandler: { "newToken" }
        )

        let error = HTTPError(
            category: .http(.forbidden),
            request: testRequest
        )

        XCTAssertFalse(strategy.canRecover(from: error))
    }

    func testAuthenticationRefreshCannotRecoverFromNetworkError() {
        let strategy = ErrorRecoveryStrategies.AuthenticationRefreshStrategy(
            tokenRefreshHandler: { "newToken" }
        )

        let error = HTTPError(
            category: .network(.noConnection),
            request: testRequest
        )

        XCTAssertFalse(strategy.canRecover(from: error))
    }

    func testAuthenticationRefreshCannotRecoverFrom500() {
        let strategy = ErrorRecoveryStrategies.AuthenticationRefreshStrategy(
            tokenRefreshHandler: { "newToken" }
        )

        let error = HTTPError(
            category: .http(.internalServerError),
            request: testRequest
        )

        XCTAssertFalse(strategy.canRecover(from: error))
    }

    // MARK: - CircuitBreakerRecoveryStrategy Tests

    func testCircuitBreakerRecoveryStrategyInitialization() async {
        let strategy = ErrorRecoveryStrategies.CircuitBreakerRecoveryStrategy(
            failureThreshold: 5,
            recoveryTimeout: 60.0
        )

        XCTAssertEqual(strategy.maxRecoveryAttempts, 1)
    }

    func testCircuitBreakerCanRecoverFromServerError() {
        let strategy = ErrorRecoveryStrategies.CircuitBreakerRecoveryStrategy()

        let error = HTTPError(
            category: .http(.internalServerError),
            request: testRequest
        )

        XCTAssertTrue(strategy.canRecover(from: error))
    }

    func testCircuitBreakerCanRecoverFrom503() {
        let strategy = ErrorRecoveryStrategies.CircuitBreakerRecoveryStrategy()

        let error = HTTPError(
            category: .http(.serviceUnavailable),
            request: testRequest
        )

        XCTAssertTrue(strategy.canRecover(from: error))
    }

    func testCircuitBreakerCannotRecoverFromClientError() {
        let strategy = ErrorRecoveryStrategies.CircuitBreakerRecoveryStrategy()

        let error = HTTPError(
            category: .http(.badRequest),
            request: testRequest
        )

        XCTAssertFalse(strategy.canRecover(from: error))
    }

    func testCircuitBreakerCannotRecoverFrom404() {
        let strategy = ErrorRecoveryStrategies.CircuitBreakerRecoveryStrategy()

        let error = HTTPError(
            category: .http(.notFound),
            request: testRequest
        )

        XCTAssertFalse(strategy.canRecover(from: error))
    }

    // MARK: - CompositeRecoveryStrategy Tests

    func testCompositeRecoveryStrategyMaxAttempts() {
        let strategy1 = ErrorRecoveryStrategies.AutomaticRetryStrategy(maxAttempts: 3)
        let strategy2 = ErrorRecoveryStrategies.AutomaticRetryStrategy(maxAttempts: 5)

        let composite = ErrorRecoveryStrategies.CompositeRecoveryStrategy(
            strategies: [strategy1, strategy2]
        )

        XCTAssertEqual(composite.maxRecoveryAttempts, 5)
    }

    func testCompositeRecoveryStrategyCanRecoverCombined() {
        let retryStrategy = ErrorRecoveryStrategies.AutomaticRetryStrategy()
        let authStrategy = ErrorRecoveryStrategies.AuthenticationRefreshStrategy(
            tokenRefreshHandler: { "newToken" }
        )

        let composite = ErrorRecoveryStrategies.CompositeRecoveryStrategy(
            strategies: [retryStrategy, authStrategy]
        )

        // Can recover from both types
        let timeoutError = HTTPError(category: .timeout, request: testRequest)
        let authError = HTTPError(
            category: .http(.unauthorized),
            request: testRequest
        )

        XCTAssertTrue(composite.canRecover(from: timeoutError))
        XCTAssertTrue(composite.canRecover(from: authError))
    }

    func testCompositeRecoveryStrategyEmptyStrategies() {
        let composite = ErrorRecoveryStrategies.CompositeRecoveryStrategy(strategies: [])

        XCTAssertEqual(composite.maxRecoveryAttempts, 0)

        let error = HTTPError(category: .timeout, request: testRequest)
        XCTAssertFalse(composite.canRecover(from: error))
    }

    // MARK: - CustomRecoveryStrategy Tests

    func testCustomRecoveryStrategyMaxAttempts() {
        let strategy = ErrorRecoveryStrategies.CustomRecoveryStrategy(
            maxRecoveryAttempts: 7,
            canRecover: { _ in true },
            recovery: { _, _, _ in
                throw HTTPError(category: .network(.serverUnreachable))
            }
        )

        XCTAssertEqual(strategy.maxRecoveryAttempts, 7)
    }

    func testCustomRecoveryStrategyCanRecoverPredicate() {
        let strategy = ErrorRecoveryStrategies.CustomRecoveryStrategy(
            canRecover: { error in
                if case let .http(status) = error.category {
                    return status.rawValue == 429
                }
                return false
            },
            recovery: { _, _, _ in
                throw HTTPError(category: .network(.serverUnreachable))
            }
        )

        let rateLimitError = HTTPError(
            category: .http(.tooManyRequests),
            request: testRequest
        )
        let otherError = HTTPError(
            category: .http(.internalServerError),
            request: testRequest
        )

        XCTAssertTrue(strategy.canRecover(from: rateLimitError))
        XCTAssertFalse(strategy.canRecover(from: otherError))
    }

    // MARK: - Factory Method Tests

    func testStandardRetryFactory() {
        let strategy = ErrorRecoveryStrategies.standardRetry()
        XCTAssertEqual(strategy.maxRecoveryAttempts, 3)
    }

    func testStandardRetryFactoryWithCustomParameters() {
        let strategy = ErrorRecoveryStrategies.standardRetry(
            maxAttempts: 5,
            baseDelay: 2.0
        )
        XCTAssertEqual(strategy.maxRecoveryAttempts, 5)
    }

    func testAggressiveRetryFactory() {
        let strategy = ErrorRecoveryStrategies.aggressiveRetry()
        XCTAssertEqual(strategy.maxRecoveryAttempts, 5)
    }

    func testConservativeRetryFactory() {
        let strategy = ErrorRecoveryStrategies.conservativeRetry()
        XCTAssertEqual(strategy.maxRecoveryAttempts, 2)
    }

    func testComprehensiveRecoveryFactory() {
        let strategy = ErrorRecoveryStrategies.comprehensive(
            tokenRefreshHandler: { "newToken" }
        )

        // Should be able to recover from various error types
        let timeoutError = HTTPError(category: .timeout, request: testRequest)
        let authError = HTTPError(
            category: .http(.unauthorized),
            request: testRequest
        )

        XCTAssertTrue(strategy.canRecover(from: timeoutError))
        XCTAssertTrue(strategy.canRecover(from: authError))
    }

    // MARK: - RecoveryStrategy Protocol Conformance Tests

    func testAutomaticRetryStrategyConformsToProtocol() {
        let strategy: any ErrorRecoveryStrategies.RecoveryStrategy =
            ErrorRecoveryStrategies.AutomaticRetryStrategy()

        XCTAssertTrue(strategy.maxRecoveryAttempts > 0)
    }

    func testAuthenticationRefreshStrategyConformsToProtocol() {
        let strategy: any ErrorRecoveryStrategies.RecoveryStrategy =
            ErrorRecoveryStrategies.AuthenticationRefreshStrategy(
                tokenRefreshHandler: { "token" }
            )

        XCTAssertEqual(strategy.maxRecoveryAttempts, 1)
    }

    func testCompositeStrategyConformsToProtocol() {
        let strategy: any ErrorRecoveryStrategies.RecoveryStrategy =
            ErrorRecoveryStrategies.CompositeRecoveryStrategy(strategies: [])

        XCTAssertNotNil(strategy)
    }

    func testCustomStrategyConformsToProtocol() {
        let strategy: any ErrorRecoveryStrategies.RecoveryStrategy =
            ErrorRecoveryStrategies.CustomRecoveryStrategy(
                canRecover: { _ in true },
                recovery: { _, _, _ in
                    throw HTTPError(category: .cancelled)
                }
            )

        XCTAssertNotNil(strategy)
    }

    // MARK: - Edge Case Tests

    func testZeroMaxAttempts() {
        let strategy = ErrorRecoveryStrategies.AutomaticRetryStrategy(maxAttempts: 0)
        XCTAssertEqual(strategy.maxRecoveryAttempts, 0)
    }

    func testLargeMaxAttempts() {
        let strategy = ErrorRecoveryStrategies.AutomaticRetryStrategy(maxAttempts: 100)
        XCTAssertEqual(strategy.maxRecoveryAttempts, 100)
    }

    func testVerySmallBaseDelay() {
        let strategy = ErrorRecoveryStrategies.AutomaticRetryStrategy(
            maxAttempts: 3,
            baseDelay: 0.001
        )
        XCTAssertEqual(strategy.maxRecoveryAttempts, 3)
    }

    func testLargeBaseDelay() {
        let strategy = ErrorRecoveryStrategies.AutomaticRetryStrategy(
            maxAttempts: 3,
            baseDelay: 60.0
        )
        XCTAssertEqual(strategy.maxRecoveryAttempts, 3)
    }

    func testZeroJitterFactor() {
        let strategy = ErrorRecoveryStrategies.AutomaticRetryStrategy(
            maxAttempts: 3,
            jitterFactor: 0.0
        )
        XCTAssertEqual(strategy.maxRecoveryAttempts, 3)
    }

    func testMaxJitterFactor() {
        let strategy = ErrorRecoveryStrategies.AutomaticRetryStrategy(
            maxAttempts: 3,
            jitterFactor: 1.0
        )
        XCTAssertEqual(strategy.maxRecoveryAttempts, 3)
    }

    func testSmallBackoffMultiplier() {
        let strategy = ErrorRecoveryStrategies.AutomaticRetryStrategy(
            maxAttempts: 3,
            backoffMultiplier: 1.0
        )
        XCTAssertEqual(strategy.maxRecoveryAttempts, 3)
    }

    func testLargeBackoffMultiplier() {
        let strategy = ErrorRecoveryStrategies.AutomaticRetryStrategy(
            maxAttempts: 3,
            backoffMultiplier: 10.0
        )
        XCTAssertEqual(strategy.maxRecoveryAttempts, 3)
    }
}

// MARK: - Test Mock HTTP Client

private final class RecoveryTestMockHTTPClient: HTTPClient, @unchecked Sendable {
    var responseQueue: [Result<HTTPResponse, HTTPError>] = []
    var requestCount = 0

    func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        requestCount += 1

        if !responseQueue.isEmpty {
            let result = responseQueue.removeFirst()
            switch result {
            case let .success(response):
                return response

            case let .failure(error):
                throw error
            }
        }

        return HTTPResponse(
            request: request,
            status: .ok,
            headers: [:],
            body: nil
        )
    }
}
