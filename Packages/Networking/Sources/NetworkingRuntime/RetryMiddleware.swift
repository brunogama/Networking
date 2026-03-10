import Foundation
import NetworkingCore

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
    public let maxAttempts: RetryAttemptCount

    /// Base delay for the first retry
    public let baseDelay: RetryDelay

    /// Maximum delay between retries
    public let maxDelay: RetryDelay

    /// Multiplier for exponential backoff
    public let backoffMultiplier: BackoffMultiplier

    /// Jitter strategy to use for retry delays
    public let jitterStrategy: JitterStrategy

    /// Predicate to determine if a request should be retried for the given error
    public let shouldRetry: @Sendable (HTTPError, RetryAttemptCount) -> RetryDecision

    /// Function to determine if retry should be attempted based on response
    public let shouldRetryResponse: @Sendable (HTTPResponse, RetryAttemptCount) -> RetryDecision

    /// Custom delay calculator (overrides exponential backoff if provided)
    public let customDelayCalculator: (@Sendable (RetryAttemptCount, RetryDelay) -> RetryDelay)?

    public init(
      maxAttempts: RetryAttemptCount = 3,
      baseDelay: RetryDelay = 1.0,
      maxDelay: RetryDelay = 60.0,
      backoffMultiplier: BackoffMultiplier = 2.0,
      jitterStrategy: JitterStrategy = .equal,
      shouldRetry: @escaping @Sendable (HTTPError, RetryAttemptCount) -> RetryDecision = Self
        .defaultShouldRetry,
      shouldRetryResponse: @escaping @Sendable (HTTPResponse, RetryAttemptCount) -> RetryDecision =
        Self
        .defaultShouldRetryResponse,
      customDelayCalculator: (@Sendable (RetryAttemptCount, RetryDelay) -> RetryDelay)? = nil
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
    public static func defaultShouldRetry(
      _ error: HTTPError,
      _ attempt: RetryAttemptCount
    ) -> RetryDecision {
      switch error.category {
      case .network(let networkError):
        return RetryDecision(shouldRetryNetworkError(networkError, attempt: attempt))

      case .http(let status):
        return RetryDecision(status.rawValue >= 500 || status.rawValue == 429)

      case .timeout:
        return RetryDecision(true)

      default:
        return RetryDecision(false)
      }
    }

    private static func shouldRetryNetworkError(
      _ networkError: HTTPError.NetworkError,
      attempt: RetryAttemptCount
    ) -> Bool {
      switch networkError {
      case .noConnection, .connectionLost, .serverUnreachable:
        return true

      case .dnsFailure:
        return attempt <= 1

      default:
        return false
      }
    }

    /// Default predicate for determining if a response should trigger a retry
    public static func defaultShouldRetryResponse(
      _ response: HTTPResponse,
      _ attempt: RetryAttemptCount
    ) -> RetryDecision {
      // Generally, we don't retry successful responses
      // This is mainly for custom logic where a 200 response might indicate a temporary issue
      RetryDecision(false)
    }
  }

  // MARK: - Properties

  private let configuration: Configuration
  let client: any HTTPClient

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
    guard configuration.shouldRetry(error, 0).rawValue else {
      throw error
    }

    var lastAttemptError = error

    for attemptValue in 1...configuration.maxAttempts.rawValue {
      let attempt = RetryAttemptCount(attemptValue)
      switch try await executeRetryAttempt(request, attempt: attempt) {
      case .success(let response):
        return response

      case .retry(let retryError):
        lastAttemptError = retryError
      }
    }

    throw lastAttemptError
  }

  // MARK: - Public Retry Information

  /// Returns the delay that would be calculated for a given attempt
  /// - Parameter attempt: The attempt number (1-based)
  /// - Returns: The delay in seconds
  public func calculateDelayForAttempt(_ attempt: RetryAttemptCount) async -> RetryDelay {
    await calculateDelay(for: attempt)
  }

  // MARK: - Private Methods

  private func calculateDelay(for attempt: RetryAttemptCount) async -> RetryDelay {
    if let customCalculator = configuration.customDelayCalculator {
      let delay = customCalculator(attempt, configuration.baseDelay)
      return RetryDelay(min(max(delay.rawValue, 0), configuration.maxDelay.rawValue))
    }

    let cappedDelay = min(exponentialBackoff(for: attempt), configuration.maxDelay.rawValue)
    let finalDelay = await jitteredDelay(for: cappedDelay)

    Task { await jitterState.setLastDelay(RetryDelay(finalDelay)) }

    return RetryDelay(max(finalDelay, 0))
  }

  private func exponentialBackoff(for attempt: RetryAttemptCount) -> Double {
    configuration.baseDelay.rawValue
      * pow(configuration.backoffMultiplier.rawValue, Double(attempt.rawValue - 1))
  }

  private func jitteredDelay(for cappedDelay: Double) async -> Double {
    switch configuration.jitterStrategy {
    case .none:
      return cappedDelay

    case .full:
      return Double.random(in: 0...cappedDelay)

    case .equal:
      return Double.random(in: (cappedDelay / 2)...cappedDelay)

    case .decorrelated:
      return await decorrelatedDelay(cappedDelay: cappedDelay)
    }
  }

  private func decorrelatedDelay(cappedDelay: Double) async -> Double {
    let lastDelay = await jitterState.lastDelay
    let base = max(configuration.baseDelay.rawValue, lastDelay.rawValue / 3)
    let jitteredDelay = Double.random(in: base...(cappedDelay * 3))
    return min(jitteredDelay, configuration.maxDelay.rawValue)
  }

  private func applyRetryDelayIfNeeded(for attempt: RetryAttemptCount) async throws {
    guard attempt > 1 else {
      return
    }

    let delay = await calculateDelay(for: attempt - 1)
    try await Task.sleep(for: .seconds(delay.rawValue))
  }

  private func retryResponseError(
    for response: HTTPResponse,
    request: HTTPRequest,
    attempt: RetryAttemptCount
  ) -> HTTPError? {
    guard configuration.shouldRetryResponse(response, attempt).rawValue else {
      return nil
    }

    guard attempt < configuration.maxAttempts else {
      return nil
    }

    return HTTPError(
      category: .http(response.status),
      request: request,
      response: response
    )
  }

  private func rethrowIfRetryShouldStop(_ error: HTTPError, attempt: RetryAttemptCount) throws {
    if attempt == configuration.maxAttempts || !configuration.shouldRetry(error, attempt).rawValue {
      throw error
    }
  }

  private func wrapRetryError(_ error: any Error, request: HTTPRequest) -> HTTPError {
    HTTPError(
      category: .network(.serverUnreachable),
      request: request,
      underlyingError: error
    )
  }

  private func executeRetryAttempt(
    _ request: HTTPRequest,
    attempt: RetryAttemptCount
  ) async throws -> RetryAttemptOutcome {
    do {
      try await applyRetryDelayIfNeeded(for: attempt)
      let response = try await client.execute(request)

      if let responseError = retryResponseError(for: response, request: request, attempt: attempt) {
        return .retry(responseError)
      }

      return .success(response)
    } catch let httpError as HTTPError {
      try rethrowIfRetryShouldStop(httpError, attempt: attempt)
      return .retry(httpError)
    } catch {
      let httpError = wrapRetryError(error, request: request)
      try rethrowIfRetryShouldStop(httpError, attempt: attempt)
      return .retry(httpError)
    }
  }
}

private enum RetryAttemptOutcome {
  case success(HTTPResponse)
  case retry(HTTPError)
}
