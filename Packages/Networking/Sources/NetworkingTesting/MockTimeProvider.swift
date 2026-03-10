import NetworkingRuntime
import NetworkingInterceptorsCompat
import NetworkingObservability
import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Mock implementation of TimeProvider for testing time-dependent logic
///
/// Allows controlling time in tests for circuit breaker, timeout, and retry logic.
/// Tracks calls to `now()` and supports time manipulation.
///
/// ## Usage Example
/// ```swift
/// let mockTime = MockTimeProvider(initialTime: Date(timeIntervalSince1970: 1000))
///
/// // Use in circuit breaker
/// let circuitBreaker = CircuitBreakerMiddleware(
///   configuration: config,
///   timeProvider: mockTime
/// )
///
/// // Advance time to test timeout
/// mockTime.advance(by: 60)
/// let now = mockTime.now()
/// #expect(now.timeIntervalSince1970 == 1060)
///
/// // Verify usage
/// try mockTime.verifyCalledAtLeast(1)
/// ```
///
/// - Note: `@unchecked Sendable` justification:
///   1. Test-only code, not production
///   2. Mutable state protected by `DispatchQueue.concurrent` with barrier writes
///   3. All public methods synchronize access through queue
///   4. Acceptable tradeoff for test ergonomics and synchronous `now()` method
public final class MockTimeProvider: TimeProvider, MockVerifiable, @unchecked Sendable {
  // MARK: - State

  private let queue = DispatchQueue(
    label: "MockTimeProvider.queue",
    attributes: .concurrent
  )

  private var currentTime: Date
  private let initialTime: Date
  private var nowCallCount: Int = 0

  // MARK: - Initialization

  /// Creates a mock time provider with specified initial time
  ///
  /// - Parameter initialTime: Starting time (default: current system time)
  public init(initialTime: Date = Date()) {
    self.currentTime = initialTime
    self.initialTime = initialTime
  }

  /// Creates a mock time provider from Unix timestamp
  ///
  /// - Parameter timestamp: Unix timestamp (seconds since epoch)
  public convenience init(timestamp: TimeInterval) {
    self.init(initialTime: Date(timeIntervalSince1970: timestamp))
  }

  // MARK: - TimeProvider Conformance

  public func now() -> Date {
    queue.sync(flags: .barrier) {
      nowCallCount += 1
      return currentTime
    }
  }

  // MARK: - Time Manipulation

  /// Set the current time to a specific date
  ///
  /// - Parameter date: New current time
  public func setTime(_ date: Date) {
    queue.sync(flags: .barrier) {
      currentTime = date
    }
  }

  /// Advance time forward by interval
  ///
  /// - Parameter interval: Time interval to advance (in seconds)
  public func advance(by interval: TimeInterval) {
    queue.sync(flags: .barrier) {
      currentTime = currentTime.addingTimeInterval(interval)
    }
  }

  /// Rewind time backward by interval
  ///
  /// - Parameter interval: Time interval to rewind (in seconds)
  public func rewind(by interval: TimeInterval) {
    queue.sync(flags: .barrier) {
      currentTime = currentTime.addingTimeInterval(-interval)
    }
  }

  /// Reset time to initial value
  public func reset() {
    queue.sync(flags: .barrier) {
      currentTime = initialTime
      nowCallCount = 0
    }
  }

  // MARK: - MockVerifiable Conformance

  nonisolated public var callCount: Int {
    get async { queue.sync { nowCallCount }
    }
  }

  // MARK: - Convenience Factories

  /// Creates a time provider frozen at specific date
  ///
  /// - Parameter date: Fixed date to return from `now()`
  /// - Returns: MockTimeProvider that always returns the same time
  public static func frozen(at date: Date) -> MockTimeProvider {
    MockTimeProvider(initialTime: date)
  }

  /// Creates a time provider frozen at Unix timestamp
  ///
  /// - Parameter timestamp: Unix timestamp (seconds since epoch)
  /// - Returns: MockTimeProvider that always returns the same time
  public static func frozen(at timestamp: TimeInterval) -> MockTimeProvider {
    MockTimeProvider(timestamp: timestamp)
  }

  // MARK: - Inspection Methods

  /// Get the current time without incrementing call count
  ///
  /// - Returns: Current time value
  public func getCurrentTime() -> Date {
    queue.sync { currentTime }
  }

  /// Get the initial time that was set at initialization
  ///
  /// - Returns: Initial time value
  public func getInitialTime() -> Date {
    queue.sync { initialTime }
  }

  /// Get the elapsed time since initialization
  ///
  /// - Returns: Time interval from initial time to current time
  public func getElapsedTime() -> TimeInterval {
    queue.sync {
      currentTime.timeIntervalSince(initialTime)
    }
  }
}
