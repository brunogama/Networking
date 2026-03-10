import Foundation
import NetworkingCore

/// Defines strategies for recovering from HTTP errors with Swift 6 compliance
public struct ErrorRecoveryStrategies: Sendable {
  // MARK: - Recovery Strategy Protocol

  /// Protocol for defining error recovery strategies
  public protocol RecoveryStrategy: Sendable {
    /// Attempts to recover from the given error
    /// - Parameters:
    ///   - error: The error to recover from
    ///   - request: The original request
    ///   - client: The HTTP client for making recovery requests
    /// - Returns: A recovered response or throws if recovery fails
    func recover(
      from error: HTTPError,
      request: HTTPRequest,
      using client: any HTTPClient
    ) async throws -> HTTPResponse

    /// Determines if this strategy can handle the given error
    func canRecover(from error: HTTPError) -> Bool

    /// The maximum number of recovery attempts for this strategy
    var maxRecoveryAttempts: Int { get }
  }

  // MARK: - Automatic Retry Strategy

  /// Implements automatic retry logic for transient errors
  public struct AutomaticRetryStrategy: RecoveryStrategy {
    private let maxAttempts: Int
    private let baseDelay: TimeInterval
    private let backoffMultiplier: Double
    private let jitterFactor: Double

    public var maxRecoveryAttempts: Int { maxAttempts }

    public init(
      maxAttempts: Int = 3,
      baseDelay: TimeInterval = 1.0,
      backoffMultiplier: Double = 2.0,
      jitterFactor: Double = 0.1
    ) {
      self.maxAttempts = maxAttempts
      self.baseDelay = baseDelay
      self.backoffMultiplier = backoffMultiplier
      self.jitterFactor = jitterFactor
    }

    public func canRecover(from error: HTTPError) -> Bool {
      error.isTransientError
    }

    public func recover(
      from error: HTTPError,
      request: HTTPRequest,
      using client: any HTTPClient
    ) async throws -> HTTPResponse {
      var lastError = error

      for attempt in 1...maxAttempts {
        let delay = calculateDelay(for: attempt)
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

        do {
          return try await client.execute(request)
        } catch let recoveryError as HTTPError {
          lastError = recoveryError

          // Stop retrying if the new error is not recoverable
          if !canRecover(from: recoveryError) {
            break
          }
        } catch {
          // Convert non-HTTP errors and stop retrying
          throw HTTPError(
            category: .network(.serverUnreachable),
            request: request,
            underlyingError: error
          )
        }
      }

      throw lastError
    }

    private func calculateDelay(for attempt: Int) -> TimeInterval {
      let exponentialDelay = baseDelay * pow(backoffMultiplier, Double(attempt - 1))
      let jitter = Double.random(in: -jitterFactor...jitterFactor) * exponentialDelay
      return max(0.1, exponentialDelay + jitter)  // Minimum 100ms delay
    }
  }

  // MARK: - Authentication Refresh Strategy

  /// Handles authentication token refresh scenarios
  public struct AuthenticationRefreshStrategy: RecoveryStrategy {
    private let tokenRefreshHandler: @Sendable () async throws -> String
    private let headerName: String
    private let tokenPrefix: String

    public let maxRecoveryAttempts: Int = 1  // Only try once per authentication error

    public init(
      headerName: String = "Authorization",
      tokenPrefix: String = "Bearer ",
      tokenRefreshHandler: @escaping @Sendable () async throws -> String
    ) {
      self.headerName = headerName
      self.tokenPrefix = tokenPrefix
      self.tokenRefreshHandler = tokenRefreshHandler
    }

    public func canRecover(from error: HTTPError) -> Bool {
      switch error.category {
      case .http(let status):
        return status.rawValue == 401

      default:
        return false
      }
    }

    public func recover(
      from error: HTTPError,
      request: HTTPRequest,
      using client: any HTTPClient
    ) async throws -> HTTPResponse {
      // Refresh the token
      let newToken = try await tokenRefreshHandler()

      // Create a new request with the refreshed token
      var updatedHeaders = request.headers
      updatedHeaders[headerName] = "\(tokenPrefix)\(newToken)"

      let updatedRequest = HTTPRequest(
        method: request.method,
        url: request.url,
        headers: updatedHeaders,
        body: request.body,
        timeout: request.timeout
      )

      // Retry with the new token
      return try await client.execute(updatedRequest)
    }
  }

  // MARK: - Circuit Breaker Recovery Strategy

  /// Implements circuit breaker pattern for handling repeated failures
  public actor CircuitBreakerRecoveryStrategy: RecoveryStrategy {
    public enum State: Sendable {
      case closed  // Normal operation
      case open  // Failing, reject requests
      case halfOpen  // Testing if service recovered
    }

    private var state: State = .closed
    private var failureCount: Int = 0
    private var lastFailureTime: Date?
    private let failureThreshold: Int
    private let recoveryTimeout: TimeInterval

    nonisolated public let maxRecoveryAttempts: Int = 1

    public init(
      failureThreshold: Int = 5,
      recoveryTimeout: TimeInterval = 60.0
    ) {
      self.failureThreshold = failureThreshold
      self.recoveryTimeout = recoveryTimeout
    }

    nonisolated public func canRecover(from error: HTTPError) -> Bool {
      error.isServerError
    }

    public func recover(
      from error: HTTPError,
      request: HTTPRequest,
      using client: any HTTPClient
    ) async throws -> HTTPResponse {
      let currentState = getCurrentState()

      switch currentState {
      case .open:
        // Circuit is open, fail fast
        throw HTTPError(
          category: .configuration("Circuit breaker is open - service unavailable"),
          request: request,
          underlyingError: error
        )

      case .closed, .halfOpen:
        // Try the request
        do {
          let response = try await client.execute(request)
          recordSuccess()
          return response
        } catch let recoveryError as HTTPError {
          recordFailure()
          throw recoveryError
        } catch {
          recordFailure()
          throw HTTPError(
            category: .network(.serverUnreachable),
            request: request,
            underlyingError: error
          )
        }
      }
    }

    private func getCurrentState() -> State {
      let now = Date()

      switch state {
      case .closed:
        return .closed

      case .open:
        // Check if we should transition to half-open
        if let lastFailure = lastFailureTime,
          now.timeIntervalSince(lastFailure) >= recoveryTimeout
        {
          state = .halfOpen
          return .halfOpen
        } else {
          return .open
        }

      case .halfOpen:
        return .halfOpen
      }
    }

    private func recordSuccess() {
      failureCount = 0
      state = .closed
    }

    private func recordFailure() {
      failureCount += 1
      lastFailureTime = Date()

      if failureCount >= failureThreshold {
        state = .open
      }
    }
  }

  // MARK: - Composite Recovery Strategy

  /// Combines multiple recovery strategies in priority order
  public struct CompositeRecoveryStrategy: RecoveryStrategy {
    private let strategies: [any RecoveryStrategy]

    public var maxRecoveryAttempts: Int {
      strategies.map(\.maxRecoveryAttempts).max() ?? 0
    }

    public init(strategies: [any RecoveryStrategy]) {
      self.strategies = strategies
    }

    public func canRecover(from error: HTTPError) -> Bool {
      strategies.contains { $0.canRecover(from: error) }
    }

    public func recover(
      from error: HTTPError,
      request: HTTPRequest,
      using client: any HTTPClient
    ) async throws -> HTTPResponse {
      var lastError = error

      // Try each strategy in order
      for strategy in strategies {
        if strategy.canRecover(from: lastError) {
          do {
            return try await strategy.recover(
              from: lastError,
              request: request,
              using: client
            )
          } catch let recoveryError as HTTPError {
            lastError = recoveryError
          } catch {
            lastError = HTTPError(
              category: .network(.serverUnreachable),
              request: request,
              underlyingError: error
            )
          }
        }
      }

      throw lastError
    }
  }

  // MARK: - Custom Recovery Strategy

  /// Allows for custom recovery logic implementation
  public struct CustomRecoveryStrategy: RecoveryStrategy {
    private let recoveryHandler:
      @Sendable (HTTPError, HTTPRequest, any HTTPClient) async throws -> HTTPResponse
    private let canRecoverPredicate: @Sendable (HTTPError) -> Bool

    public let maxRecoveryAttempts: Int

    public init(
      maxRecoveryAttempts: Int = 1,
      canRecover: @escaping @Sendable (HTTPError) -> Bool,
      recovery:
        @escaping @Sendable (HTTPError, HTTPRequest, any HTTPClient) async throws ->
        HTTPResponse
    ) {
      self.maxRecoveryAttempts = maxRecoveryAttempts
      self.canRecoverPredicate = canRecover
      self.recoveryHandler = recovery
    }

    public func canRecover(from error: HTTPError) -> Bool {
      canRecoverPredicate(error)
    }

    public func recover(
      from error: HTTPError,
      request: HTTPRequest,
      using client: any HTTPClient
    ) async throws -> HTTPResponse {
      try await recoveryHandler(error, request, client)
    }
  }
}

// MARK: - Convenience Factory Methods

extension ErrorRecoveryStrategies {
  /// Creates a standard retry strategy for common transient errors
  public static func standardRetry(
    maxAttempts: Int = 3,
    baseDelay: TimeInterval = 1.0
  ) -> AutomaticRetryStrategy {
    AutomaticRetryStrategy(
      maxAttempts: maxAttempts,
      baseDelay: baseDelay,
      backoffMultiplier: 2.0,
      jitterFactor: 0.1
    )
  }

  /// Creates an aggressive retry strategy with shorter delays and more attempts
  public static func aggressiveRetry() -> AutomaticRetryStrategy {
    AutomaticRetryStrategy(
      maxAttempts: 5,
      baseDelay: 0.5,
      backoffMultiplier: 1.5,
      jitterFactor: 0.05
    )
  }

  /// Creates a conservative retry strategy with longer delays and fewer attempts
  public static func conservativeRetry() -> AutomaticRetryStrategy {
    AutomaticRetryStrategy(
      maxAttempts: 2,
      baseDelay: 2.0,
      backoffMultiplier: 3.0,
      jitterFactor: 0.2
    )
  }

  /// Creates a comprehensive recovery strategy combining multiple approaches
  public static func comprehensive(
    tokenRefreshHandler: @escaping @Sendable () async throws -> String
  ) -> CompositeRecoveryStrategy {
    CompositeRecoveryStrategy(strategies: [
      AuthenticationRefreshStrategy(tokenRefreshHandler: tokenRefreshHandler),
      AutomaticRetryStrategy(),
      CircuitBreakerRecoveryStrategy(),
    ])
  }
}
