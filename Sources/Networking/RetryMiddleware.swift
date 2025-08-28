import Foundation

/// Middleware that retries failed requests with exponential backoff and jitter.
///
/// This implementation includes:
/// - Exponential backoff with configurable multiplier
/// - Full or equal jitter to prevent thundering herd
/// - Configurable retry conditions
/// - Detailed retry attempt tracking
public struct RetryMiddleware: HTTPErrorMiddleware {
  // MARK: - Jitter Strategy

  /// Strategy for adding jitter to retry delays
  public enum JitterStrategy: Sendable {
    /// No jitter - uses exact exponential backoff
    case none

    /// Full jitter - random delay between 0 and calculated backoff
    case full

    /// Equal jitter - random delay between half and full calculated backoff
    case equal

    /// Decorrelated jitter - uses previous delay as base for random calculation
    case decorrelated
  }

  // MARK: - Configuration

  public struct Configuration: Sendable {
    /// Maximum number of retry attempts (not including the initial attempt)
    public let maxAttempts: Int

    /// Base delay for the first retry
    public let baseDelay: TimeInterval

    /// Maximum delay between retries
    public let maxDelay: TimeInterval

    /// Multiplier for exponential backoff
    public let backoffMultiplier: Double

    /// Jitter strategy to use for retry delays
    public let jitterStrategy: JitterStrategy

    /// Predicate to determine if a request should be retried for the given error
    public let shouldRetry: @Sendable (HTTPError, Int) -> Bool

    /// Function to determine if retry should be attempted based on response
    public let shouldRetryResponse: @Sendable (HTTPResponse, Int) -> Bool

    /// Custom delay calculator (overrides exponential backoff if provided)
    public let customDelayCalculator: (@Sendable (Int, TimeInterval) -> TimeInterval)?

    public init(
      maxAttempts: Int = 3,
      baseDelay: TimeInterval = 1.0,
      maxDelay: TimeInterval = 60.0,
      backoffMultiplier: Double = 2.0,
      jitterStrategy: JitterStrategy = .equal,
      shouldRetry: @escaping @Sendable (HTTPError, Int) -> Bool = Self.defaultShouldRetry,
      shouldRetryResponse: @escaping @Sendable (HTTPResponse, Int) -> Bool = Self
        .defaultShouldRetryResponse,
      customDelayCalculator: (@Sendable (Int, TimeInterval) -> TimeInterval)? = nil
    ) {
      self.maxAttempts = maxAttempts
      self.baseDelay = baseDelay
      self.maxDelay = maxDelay
      self.backoffMultiplier = backoffMultiplier
      self.jitterStrategy = jitterStrategy
      self.shouldRetry = shouldRetry
      self.shouldRetryResponse = shouldRetryResponse
      self.customDelayCalculator = customDelayCalculator
    }

    /// Default predicate for determining if an error should be retried
    public static func defaultShouldRetry(_ error: HTTPError, _ attempt: Int) -> Bool {
      switch error.category {
      case .network(.noConnection), .network(.connectionLost), .network(.serverUnreachable):
        return true

      case .network(.dnsFailure):
        return attempt <= 1  // Only retry DNS failures once
      case .http(let status) where status.rawValue >= 500:
        return true
      case .http(let status) where status.rawValue == 429:  // Too Many Requests
        return true

      case .timeout:
        return true

      default:
        return false
      }
    }

    /// Default predicate for determining if a response should trigger a retry
    public static func defaultShouldRetryResponse(_ response: HTTPResponse, _ attempt: Int) -> Bool
    {
      // Generally, we don't retry successful responses
      // This is mainly for custom logic where a 200 response might indicate a temporary issue
      false
    }
  }

  // MARK: - Properties

  private let configuration: Configuration
  private let client: any HTTPClient

  // State for decorrelated jitter (using actor for thread-safe access)
  private let jitterState = JitterState()

  // MARK: - Initialization

  public init(configuration: Configuration, client: any HTTPClient) {
    self.configuration = configuration
    self.client = client
  }

  // MARK: - HTTPErrorMiddleware

  public func handleError(
    _ error: HTTPError,
    for request: HTTPRequest
  ) async throws -> HTTPResponse {
    guard configuration.shouldRetry(error, 0) else {
      throw error
    }

    var lastAttemptError = error

    for attempt in 1...configuration.maxAttempts {
      do {
        if attempt > 1 {
          let delay = await calculateDelay(for: attempt - 1)
          try await Task.sleep(for: .seconds(delay))
        }

        let response = try await client.execute(request)

        // Check if the response indicates we should retry
        if configuration.shouldRetryResponse(response, attempt)
          && attempt < configuration.maxAttempts
        {
          // Convert response to error for retry logic
          let responseError = HTTPError(
            category: .http(response.status),
            request: request,
            response: response
          )
          lastAttemptError = responseError
          continue
        }

        return response
      } catch let retryError as HTTPError {
        lastAttemptError = retryError

        if attempt == configuration.maxAttempts || !configuration.shouldRetry(retryError, attempt) {
          throw retryError
        }
        // Continue to next iteration for retry
      } catch {
        // Convert non-HTTP errors
        let httpError = HTTPError(
          category: .network(.serverUnreachable),
          request: request,
          underlyingError: error
        )
        lastAttemptError = httpError

        if attempt == configuration.maxAttempts || !configuration.shouldRetry(httpError, attempt) {
          throw httpError
        }
      }
    }

    // If we've exhausted all retries, throw the last error
    throw lastAttemptError
  }

  // MARK: - Public Retry Information

  /// Returns the delay that would be calculated for a given attempt
  /// - Parameter attempt: The attempt number (1-based)
  /// - Returns: The delay in seconds
  public func calculateDelayForAttempt(_ attempt: Int) async -> TimeInterval {
    await calculateDelay(for: attempt)
  }

  // MARK: - Private Methods

  private func calculateDelay(for attempt: Int) async -> TimeInterval {
    // Use custom delay calculator if provided
    if let customCalculator = configuration.customDelayCalculator {
      let delay = customCalculator(attempt, configuration.baseDelay)
      return min(max(delay, 0), configuration.maxDelay)
    }

    // Calculate base exponential backoff
    let exponentialDelay =
      configuration.baseDelay * pow(configuration.backoffMultiplier, Double(attempt - 1))
    let cappedDelay = min(exponentialDelay, configuration.maxDelay)

    // Apply jitter based on strategy
    let finalDelay: TimeInterval
    switch configuration.jitterStrategy {
    case .none:
      finalDelay = cappedDelay

    case .full:
      // Random delay between 0 and cappedDelay
      finalDelay = Double.random(in: 0...cappedDelay)

    case .equal:
      // Random delay between cappedDelay/2 and cappedDelay
      finalDelay = Double.random(in: (cappedDelay / 2)...cappedDelay)

    case .decorrelated:
      // Decorrelated jitter uses previous delay as base
      let lastDelay = await jitterState.lastDelay
      let base = max(configuration.baseDelay, lastDelay / 3)
      let jitteredDelay = Double.random(in: base...(cappedDelay * 3))
      finalDelay = min(jitteredDelay, configuration.maxDelay)
    }

    // Update last delay for decorrelated jitter
    Task { await jitterState.setLastDelay(finalDelay) }

    return max(finalDelay, 0)  // Ensure non-negative delay
  }
}

// MARK: - Recovery Strategy Integration

extension RetryMiddleware {
  /// Configuration that includes recovery strategy integration
  public struct RecoveryConfiguration: Sendable {
    /// The underlying retry configuration
    public let retryConfig: Configuration

    /// Recovery strategies to apply before retry logic
    public let recoveryStrategies: [any ErrorRecoveryStrategies.RecoveryStrategy]

    /// Whether to use recovery strategies first or retry first
    public let prioritizeRecovery: Bool

    public init(
      retryConfig: Configuration = Configuration(),
      recoveryStrategies: [any ErrorRecoveryStrategies.RecoveryStrategy] = [],
      prioritizeRecovery: Bool = true
    ) {
      self.retryConfig = retryConfig
      self.recoveryStrategies = recoveryStrategies
      self.prioritizeRecovery = prioritizeRecovery
    }
  }

  /// Enhanced retry middleware with recovery strategy integration
  public struct WithRecoveryStrategies: HTTPErrorMiddleware {
    private let recoveryConfig: RecoveryConfiguration
    private let baseMiddleware: RetryMiddleware

    public init(configuration: RecoveryConfiguration, client: any HTTPClient) {
      self.recoveryConfig = configuration
      self.baseMiddleware = RetryMiddleware(
        configuration: configuration.retryConfig,
        client: client
      )
    }

    public func handleError(
      _ error: HTTPError,
      for request: HTTPRequest
    ) async throws -> HTTPResponse {
      if recoveryConfig.prioritizeRecovery {
        // Try recovery strategies first, then fall back to retry
        if let recoveredResponse = await tryRecoveryStrategies(error, request: request) {
          return recoveredResponse
        }

        // If recovery fails, use standard retry logic
        return try await baseMiddleware.handleError(error, for: request)
      } else {
        // Try retry first, then recovery on final failure
        do {
          return try await baseMiddleware.handleError(error, for: request)
        } catch let finalError as HTTPError {
          // If retry exhausted, try recovery strategies
          if let recoveredResponse = await tryRecoveryStrategies(finalError, request: request) {
            return recoveredResponse
          }
          throw finalError
        }
      }
    }

    private func tryRecoveryStrategies(
      _ error: HTTPError,
      request: HTTPRequest
    ) async -> HTTPResponse? {
      for strategy in recoveryConfig.recoveryStrategies {
        if strategy.canRecover(from: error) {
          do {
            return try await strategy.recover(
              from: error,
              request: request,
              using: baseMiddleware.client
            )
          } catch {
            // Continue to next strategy
            continue
          }
        }
      }
      return nil
    }
  }
}

// MARK: - Convenience Factory Methods

extension RetryMiddleware {
  /// Creates a retry middleware with aggressive retry settings
  /// - Parameter client: The HTTP client to use
  /// - Returns: A configured retry middleware with shorter delays and more attempts
  public static func aggressive(client: any HTTPClient) -> RetryMiddleware {
    RetryMiddleware(
      configuration: Configuration(
        maxAttempts: 5,
        baseDelay: 0.5,
        maxDelay: 10.0,
        backoffMultiplier: 1.5,
        jitterStrategy: .equal
      ),
      client: client
    )
  }

  /// Creates a retry middleware with conservative retry settings
  /// - Parameter client: The HTTP client to use
  /// - Returns: A configured retry middleware with longer delays and fewer attempts
  public static func conservative(client: any HTTPClient) -> RetryMiddleware {
    RetryMiddleware(
      configuration: Configuration(
        maxAttempts: 2,
        baseDelay: 2.0,
        maxDelay: 30.0,
        backoffMultiplier: 2.0,
        jitterStrategy: .full
      ),
      client: client
    )
  }

  /// Creates a retry middleware optimized for network-related errors only
  /// - Parameter client: The HTTP client to use
  /// - Returns: A configured retry middleware that only retries network errors
  public static func networkErrorsOnly(client: any HTTPClient) -> RetryMiddleware {
    RetryMiddleware(
      configuration: Configuration(
        shouldRetry: { error, attempt in
          switch error.category {
          case .network:
            return attempt <= 3

          case .timeout:
            return attempt <= 2

          default:
            return false
          }
        }
      ),
      client: client
    )
  }

  /// Creates a retry middleware with custom jitter strategy
  /// - Parameters:
  ///   - client: The HTTP client to use
  ///   - jitterStrategy: The jitter strategy to apply
  /// - Returns: A configured retry middleware with the specified jitter strategy
  public static func withJitter(
    client: any HTTPClient,
    jitterStrategy: JitterStrategy
  ) -> RetryMiddleware {
    RetryMiddleware(
      configuration: Configuration(jitterStrategy: jitterStrategy),
      client: client
    )
  }

  /// Creates an enhanced retry middleware with authentication recovery
  /// - Parameters:
  ///   - client: The HTTP client to use
  ///   - tokenRefreshHandler: Handler for refreshing authentication tokens
  /// - Returns: A retry middleware with authentication recovery strategy
  public static func withAuthenticationRecovery(
    client: any HTTPClient,
    tokenRefreshHandler: @escaping @Sendable () async throws -> String
  ) -> WithRecoveryStrategies {
    let recoveryConfig = RecoveryConfiguration(
      recoveryStrategies: [
        ErrorRecoveryStrategies.AuthenticationRefreshStrategy(
          tokenRefreshHandler: tokenRefreshHandler
        ),
        ErrorRecoveryStrategies.standardRetry(),
      ]
    )
    return WithRecoveryStrategies(configuration: recoveryConfig, client: client)
  }

  /// Creates a comprehensive retry middleware with multiple recovery strategies
  /// - Parameters:
  ///   - client: The HTTP client to use
  ///   - tokenRefreshHandler: Handler for refreshing authentication tokens (optional)
  /// - Returns: A retry middleware with comprehensive recovery strategies
  public static func comprehensive(
    client: any HTTPClient,
    tokenRefreshHandler: (@Sendable () async throws -> String)? = nil
  ) -> WithRecoveryStrategies {
    var strategies: [any ErrorRecoveryStrategies.RecoveryStrategy] = []

    if let tokenHandler = tokenRefreshHandler {
      strategies.append(
        ErrorRecoveryStrategies.AuthenticationRefreshStrategy(
          tokenRefreshHandler: tokenHandler
        )
      )
    }

    let additionalStrategies: [any ErrorRecoveryStrategies.RecoveryStrategy] = [
      ErrorRecoveryStrategies.standardRetry(),
      ErrorRecoveryStrategies.CircuitBreakerRecoveryStrategy(),
    ]
    strategies.append(contentsOf: additionalStrategies)

    let recoveryConfig = RecoveryConfiguration(
      retryConfig: Configuration(maxAttempts: 3, baseDelay: 1.0),
      recoveryStrategies: strategies,
      prioritizeRecovery: true
    )

    return WithRecoveryStrategies(configuration: recoveryConfig, client: client)
  }

  /// Creates a retry middleware with custom recovery strategies
  /// - Parameters:
  ///   - client: The HTTP client to use
  ///   - strategies: Custom recovery strategies to use
  ///   - retryConfig: Optional custom retry configuration
  ///   - prioritizeRecovery: Whether to try recovery before retry (default: true)
  /// - Returns: A retry middleware with custom recovery strategies
  public static func withRecoveryStrategies(
    client: any HTTPClient,
    strategies: [any ErrorRecoveryStrategies.RecoveryStrategy],
    retryConfig: Configuration = Configuration(),
    prioritizeRecovery: Bool = true
  ) -> WithRecoveryStrategies {
    let recoveryConfig = RecoveryConfiguration(
      retryConfig: retryConfig,
      recoveryStrategies: strategies,
      prioritizeRecovery: prioritizeRecovery
    )
    return WithRecoveryStrategies(configuration: recoveryConfig, client: client)
  }
}

// MARK: - Jitter State Management

/// Actor to manage jitter state in a thread-safe way
private actor JitterState {
  private(set) var lastDelay: TimeInterval = 0

  func setLastDelay(_ delay: TimeInterval) {
    lastDelay = delay
  }
}
