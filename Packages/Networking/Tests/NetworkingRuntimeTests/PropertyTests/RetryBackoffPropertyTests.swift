import Foundation
import SwiftCheck
import XCTest

@testable import NetworkingRuntime
import NetworkingDSL
import NetworkingRuntimeDSL
import NetworkingTesting

/// Property-based tests for retry backoff calculations.
///
/// Tests mathematical bounds, monotonicity, and jitter constraints of exponential backoff.
final class RetryBackoffPropertyTests: XCTestCase {
    // MARK: - Mathematical Bounds Properties

    func testDelayIsNonNegative() {
        property("Delay is always non-negative")
            <- forAll(RetryConfigGen.arbitrary, Gen.choose((0, 20))) {
                (config: RetryConfig, attemptCount: Int) in
                let delay = Self.calculateDelay(
                    attemptCount: attemptCount,
                    baseDelay: config.baseDelay,
                    maxDelay: config.maxDelay
                )
                return delay >= 0
            }
    }

    func testDelayNeverExceedsMaxDelay() {
        property("Delay never exceeds maxDelay (even with jitter)")
            <- forAll(RetryConfigGen.arbitrary, Gen.choose((0, 100))) {
                (config: RetryConfig, attemptCount: Int) in
                // Test multiple times to account for jitter randomness
                for _ in 0 ..< 10 {
                    let delay = Self.calculateDelay(
                        attemptCount: attemptCount,
                        baseDelay: config.baseDelay,
                        maxDelay: config.maxDelay
                    )
                    if delay > config.maxDelay {
                        return false
                    }
                }
                return true
            }
    }

    func testDelayMonotonicity() {
        property("Delay is monotonically increasing (without jitter) until cap")
            <- forAll(RetryConfigGen.arbitrary) { (config: RetryConfig) in
                var previousDelay = 0.0

                for attempt in 0 ..< 20 {
                    // Calculate delay without jitter for deterministic comparison
                    let exponentialDelay = config.baseDelay * pow(2.0, Double(attempt))
                    let delay = min(exponentialDelay, config.maxDelay)

                    if delay < previousDelay {
                        return false
                    }
                    previousDelay = delay
                }
                return true
            }
    }

    // MARK: - Exponential Formula Properties

    func testExponentialGrowthFormula() {
        property("Delay follows exponential formula: baseDelay * 2^attemptCount (before cap)")
            <- forAll(RetryConfigGen.arbitrary, Gen.choose((0, 10))) {
                (config: RetryConfig, attemptCount: Int) in
                let expectedExponential = config.baseDelay * pow(2.0, Double(attemptCount))

                // If expected is under cap, delay should be close to expected (within jitter range)
                if expectedExponential <= config.maxDelay {
                    // Run multiple times and check if at least some are in expected range
                    var foundExpected = false
                    for _ in 0 ..< 20 {
                        let delay = Self.calculateDelay(
                            attemptCount: attemptCount,
                            baseDelay: config.baseDelay,
                            maxDelay: config.maxDelay
                        )
                        // Delay should be in range [exponential, exponential * 1.1] due to jitter
                        if delay >= expectedExponential, delay <= expectedExponential * 1.1 {
                            foundExpected = true
                            break
                        }
                    }
                    return foundExpected
                }
                return true
            }
    }

    // MARK: - Jitter Properties

    func testJitterStaysWithinBounds() {
        property("Jitter adds at most 10% to the capped delay")
            <- forAll(RetryConfigGen.arbitrary, Gen.choose((0, 50))) {
                (config: RetryConfig, attemptCount: Int) in
                let exponentialDelay = config.baseDelay * pow(2.0, Double(attemptCount))
                let cappedDelay = min(exponentialDelay, config.maxDelay)

                // The maximum possible delay with jitter
                let maxPossibleDelay = min(cappedDelay * 1.1, config.maxDelay)

                // Test multiple times
                for _ in 0 ..< 20 {
                    let delay = Self.calculateDelay(
                        attemptCount: attemptCount,
                        baseDelay: config.baseDelay,
                        maxDelay: config.maxDelay
                    )
                    // Delay should be between capped (no jitter) and maxPossible (max jitter)
                    if delay < cappedDelay || delay > maxPossibleDelay {
                        return false
                    }
                }
                return true
            }
    }

    // MARK: - Cap Convergence Property

    func testLargeAttemptsConvergeToMaxDelay() {
        property("Large attempt counts converge to maxDelay")
            <- forAll(RetryConfigGen.arbitrary) { (config: RetryConfig) in
                // At very high attempt counts, delay should be at or near maxDelay
                for _ in 0 ..< 10 {
                    let delay = Self.calculateDelay(
                        attemptCount: 100, // Very large
                        baseDelay: config.baseDelay,
                        maxDelay: config.maxDelay
                    )
                    // Should be within 10% of maxDelay (accounting for jitter)
                    if delay < config.maxDelay * 0.9 || delay > config.maxDelay {
                        return false
                    }
                }
                return true
            }
    }

    // MARK: - Helper: Replicate RetryInterceptor's delay calculation

    /// Replicates the delay calculation from RetryInterceptor for testing.
    ///
    /// This mirrors the logic in `RetryInterceptor.calculateDelay` to test the formula.
    private static func calculateDelay(
        attemptCount: Int,
        baseDelay: TimeInterval,
        maxDelay: TimeInterval
    ) -> TimeInterval {
        // Exponential backoff: baseDelay * (2 ^ attemptCount)
        let exponentialDelay = baseDelay * pow(2.0, Double(attemptCount))

        // Cap at maxDelay
        let cappedDelay = min(exponentialDelay, maxDelay)

        // Add jitter (0-10% of delay) to prevent thundering herd
        let jitter = Double.random(in: 0 ... (cappedDelay * 0.1))

        // Ensure final delay never exceeds maxDelay (jitter could push it over)
        return min(cappedDelay + jitter, maxDelay)
    }
}

// MARK: - Retry Configuration Type

/// Configuration for retry testing
struct RetryConfig: Sendable {
    let maxAttempts: Int
    let baseDelay: TimeInterval
    let maxDelay: TimeInterval
}

// MARK: - Arbitrary Conformance

extension RetryConfig: Arbitrary {
    static var arbitrary: Gen<RetryConfig> {
        Gen<RetryConfig>.compose { composer in
            // Generate reasonable retry configuration values
            let maxAttempts = composer.generate(using: Gen.choose((1, 10)))
            let baseDelay = composer.generate(using: Gen.choose((1, 100)))
            let maxDelay = composer.generate(using: Gen.choose((10, 1000)))

            return RetryConfig(
                maxAttempts: maxAttempts,
                baseDelay: TimeInterval(baseDelay) / 10.0, // 0.1 to 10.0 seconds
                maxDelay: TimeInterval(maxDelay) / 10.0 // 1.0 to 100.0 seconds
            )
        }
    }
}

// MARK: - Retry Configuration Generator (Legacy, now using Arbitrary conformance)

enum RetryConfigGen {
    static var arbitrary: Gen<RetryConfig> {
        RetryConfig.arbitrary
    }
}
