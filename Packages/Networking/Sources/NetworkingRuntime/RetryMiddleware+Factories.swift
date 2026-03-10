import NetworkingCore

extension RetryMiddleware {
  /// Creates a retry middleware with aggressive retry settings.
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

  /// Creates a retry middleware with conservative retry settings.
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

  /// Creates a retry middleware optimized for network-related errors only.
  public static func networkErrorsOnly(client: any HTTPClient) -> RetryMiddleware {
    RetryMiddleware(
      configuration: Configuration(
        shouldRetry: { error, attempt in
          switch error.category {
          case .network:
            return RetryDecision(attempt <= 3)

          case .timeout:
            return RetryDecision(attempt <= 2)

          default:
            return RetryDecision(false)
          }
        }
      ),
      client: client
    )
  }

  /// Creates a retry middleware with custom jitter strategy.
  public static func withJitter(
    client: any HTTPClient,
    jitterStrategy: JitterStrategy
  ) -> RetryMiddleware {
    RetryMiddleware(
      configuration: Configuration(jitterStrategy: jitterStrategy),
      client: client
    )
  }

  /// Creates an enhanced retry middleware with authentication recovery.
  public static func withAuthenticationRecovery(
    client: any HTTPClient,
    tokenRefreshHandler: @escaping @Sendable () async throws -> BearerTokenValue
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

  /// Creates a comprehensive retry middleware with multiple recovery strategies.
  public static func comprehensive(
    client: any HTTPClient,
    tokenRefreshHandler: (@Sendable () async throws -> BearerTokenValue)? = nil
  ) -> WithRecoveryStrategies {
    var strategies: [any ErrorRecoveryStrategies.RecoveryStrategy] = []

    if let tokenHandler = tokenRefreshHandler {
      strategies.append(
        ErrorRecoveryStrategies.AuthenticationRefreshStrategy(
          tokenRefreshHandler: tokenHandler
        )
      )
    }

    strategies.append(ErrorRecoveryStrategies.standardRetry())
    strategies.append(ErrorRecoveryStrategies.CircuitBreakerRecoveryStrategy())

    let recoveryConfig = RecoveryConfiguration(
      retryConfig: Configuration(maxAttempts: 3, baseDelay: 1.0),
      recoveryStrategies: strategies,
      prioritizeRecovery: true
    )

    return WithRecoveryStrategies(configuration: recoveryConfig, client: client)
  }

  /// Creates a retry middleware with custom recovery strategies.
  public static func withRecoveryStrategies(
    client: any HTTPClient,
    strategies: [any ErrorRecoveryStrategies.RecoveryStrategy],
    retryConfig: Configuration = Configuration(),
    prioritizeRecovery: RetryDecision = true
  ) -> WithRecoveryStrategies {
    let recoveryConfig = RecoveryConfiguration(
      retryConfig: retryConfig,
      recoveryStrategies: strategies,
      prioritizeRecovery: prioritizeRecovery
    )
    return WithRecoveryStrategies(configuration: recoveryConfig, client: client)
  }
}
