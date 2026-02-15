import Foundation

/// Protocol for providing current time, enabling deterministic testing.
public protocol TimeProvider: Sendable {
  /// Returns the current date/time.
  func now() -> Date
}

/// Default time provider using system clock.
public struct SystemTimeProvider: TimeProvider {
  public init() {}

  public func now() -> Date {
    Date()
  }
}

/// Circuit breaker middleware that prevents cascading failures by temporarily stopping requests
/// to failing services, allowing them time to recover.
///
/// The circuit breaker has three states:
/// - **Closed**: Normal operation, requests pass through
/// - **Open**: Requests are blocked and fail immediately
/// - **Half-Open**: Limited requests are allowed to test recovery
public actor CircuitBreakerMiddleware: HTTPErrorMiddleware {
  // MARK: - State

  /// The possible states of the circuit breaker
  public enum State: Sendable {
    case closed
    case open(openedAt: Date)
    case halfOpen
  }

  // MARK: - Configuration

  /// Configuration for the circuit breaker behavior
  public struct Configuration: Sendable {
    /// Number of consecutive failures required to open the circuit
    public let failureThreshold: Int

    /// Time interval to wait before transitioning from open to half-open
    public let recoveryTimeout: TimeInterval

    /// Number of successful requests required in half-open state to close the circuit
    public let successThreshold: Int

    /// Time window for counting failures
    public let rollingWindow: TimeInterval

    /// Predicate to determine if an error should count as a failure
    public let shouldCountFailure: @Sendable (HTTPError) -> Bool

    public init(
      failureThreshold: Int = 5,
      recoveryTimeout: TimeInterval = 60.0,
      successThreshold: Int = 3,
      rollingWindow: TimeInterval = 120.0,
      shouldCountFailure: @escaping @Sendable (HTTPError) -> Bool = Self.defaultShouldCountFailure
    ) {
      self.failureThreshold = failureThreshold
      self.recoveryTimeout = recoveryTimeout
      self.successThreshold = successThreshold
      self.rollingWindow = rollingWindow
      self.shouldCountFailure = shouldCountFailure
    }

    /// Default predicate for determining if an error should count as a failure
    public static func defaultShouldCountFailure(_ error: HTTPError) -> Bool {
      switch error.category {
      case .network(.serverUnreachable), .network(.connectionLost), .network(.noConnection):
        return true

      case .http(let status) where status.rawValue >= 500:
        return true

      case .timeout:
        return true

      default:
        return false
      }
    }
  }

  // MARK: - Properties

  private let configuration: Configuration
  private let client: any HTTPClient
  private let timeProvider: any TimeProvider

  // Circuit breaker state
  private var state: State = .closed
  private var failureCount: Int = 0
  private var successCount: Int = 0
  private var failureTimes: [Date] = []

  // MARK: - Initialization

  /// Creates a new circuit breaker middleware
  /// - Parameters:
  ///   - configuration: The circuit breaker configuration
  ///   - client: The HTTP client to use for requests
  ///   - timeProvider: Provider for current time (defaults to system clock)
  public init(
    configuration: Configuration,
    client: any HTTPClient,
    timeProvider: any TimeProvider = SystemTimeProvider()
  ) {
    self.configuration = configuration
    self.client = client
    self.timeProvider = timeProvider
  }

  // MARK: - HTTPErrorMiddleware

  public func handleError(
    _ error: HTTPError,
    for request: HTTPRequest
  ) async throws -> HTTPResponse {
    // Check if circuit is open and should remain open
    if case .open(let openedAt) = state {
      let timeSinceOpened = timeProvider.now().timeIntervalSince(openedAt)
      if timeSinceOpened < configuration.recoveryTimeout {
        throw HTTPError(
          category: .network(.serverUnreachable),
          request: request,
          underlyingError: CircuitBreakerError.circuitOpen
        )
      } else {
        // Transition to half-open state
        await transitionToHalfOpen()
      }
    }

    // If we're here, the circuit is either closed or half-open
    // Attempt the request
    do {
      let response = try await client.execute(request)
      await recordSuccess()
      return response
    } catch let requestError as HTTPError {
      await recordFailure(requestError)
      throw requestError
    } catch {
      let httpError = HTTPError(
        category: .network(.serverUnreachable),
        request: request,
        underlyingError: error
      )
      await recordFailure(httpError)
      throw httpError
    }
  }

  // MARK: - Public State Access

  /// Returns the current state of the circuit breaker
  public var currentState: State {
    get async { state }
  }

  /// Returns the current failure count
  public var currentFailureCount: Int {
    get async { failureCount }
  }

  /// Manually resets the circuit breaker to closed state
  public func reset() async {
    state = .closed
    failureCount = 0
    successCount = 0
    failureTimes.removeAll()
  }

  // MARK: - Private Methods

  private func recordSuccess() async {
    switch state {
    case .closed:
      // Reset failure count on success
      failureCount = 0
      failureTimes.removeAll()

    case .halfOpen:
      successCount += 1
      if successCount >= configuration.successThreshold {
        await transitionToClosed()
      }

    case .open:
      // This shouldn't happen, but reset if it does
      await transitionToClosed()
    }
  }

  private func recordFailure(_ error: HTTPError) async {
    guard configuration.shouldCountFailure(error) else {
      return
    }

    let now = timeProvider.now()

    // Clean up old failures outside the rolling window
    let cutoffTime = now.addingTimeInterval(-configuration.rollingWindow)
    failureTimes = failureTimes.filter { $0 >= cutoffTime }

    // Add new failure
    failureTimes.append(now)
    failureCount = failureTimes.count

    switch state {
    case .closed:
      if failureCount >= configuration.failureThreshold {
        await transitionToOpen()
      }

    case .halfOpen:
      // Any failure in half-open state should open the circuit
      await transitionToOpen()

    case .open:
      // Already open, just update the failure count
      break
    }
  }

  private func transitionToClosed() async {
    state = .closed
    failureCount = 0
    successCount = 0
    failureTimes.removeAll()
  }

  private func transitionToOpen() async {
    state = .open(openedAt: timeProvider.now())
    successCount = 0
  }

  private func transitionToHalfOpen() async {
    state = .halfOpen
    successCount = 0
  }
}

// MARK: - Circuit Breaker Error

/// Error thrown when the circuit breaker is open
public struct CircuitBreakerError: Error, Sendable, LocalizedError {
  public static let circuitOpen = Self()

  private init() {}

  public var errorDescription: String? {
    "Circuit breaker is open - requests are being blocked to allow service recovery"
  }
}

// MARK: - Convenience Factory

extension CircuitBreakerMiddleware {
  /// Creates a circuit breaker with default configuration
  /// - Parameters:
  ///   - client: The HTTP client to wrap
  ///   - timeProvider: Provider for current time (defaults to system clock)
  /// - Returns: A configured circuit breaker middleware
  public static func `default`(
    client: any HTTPClient,
    timeProvider: any TimeProvider = SystemTimeProvider()
  ) -> CircuitBreakerMiddleware {
    CircuitBreakerMiddleware(
      configuration: Configuration(),
      client: client,
      timeProvider: timeProvider
    )
  }

  /// Creates a circuit breaker with aggressive settings for unstable services
  /// - Parameters:
  ///   - client: The HTTP client to wrap
  ///   - timeProvider: Provider for current time (defaults to system clock)
  /// - Returns: A configured circuit breaker middleware with lower thresholds
  public static func aggressive(
    client: any HTTPClient,
    timeProvider: any TimeProvider = SystemTimeProvider()
  ) -> CircuitBreakerMiddleware {
    CircuitBreakerMiddleware(
      configuration: Configuration(
        failureThreshold: 3,
        recoveryTimeout: 30.0,
        successThreshold: 2,
        rollingWindow: 60.0
      ),
      client: client,
      timeProvider: timeProvider
    )
  }

  /// Creates a circuit breaker with lenient settings for stable services
  /// - Parameters:
  ///   - client: The HTTP client to wrap
  ///   - timeProvider: Provider for current time (defaults to system clock)
  /// - Returns: A configured circuit breaker middleware with higher thresholds
  public static func lenient(
    client: any HTTPClient,
    timeProvider: any TimeProvider = SystemTimeProvider()
  ) -> CircuitBreakerMiddleware {
    CircuitBreakerMiddleware(
      configuration: Configuration(
        failureThreshold: 10,
        recoveryTimeout: 120.0,
        successThreshold: 5,
        rollingWindow: 300.0
      ),
      client: client,
      timeProvider: timeProvider
    )
  }
}
