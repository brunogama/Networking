import Foundation

/// Response interceptor that automatically retries failed requests with exponential backoff.
///
/// Retries transient failures (network errors, 5xx server errors, 408 timeout, 429 rate limit)
/// using exponential backoff with jitter to prevent thundering herd. Configurable retry limits
/// and delay strategies provide fine-grained control over retry behavior.
///
/// ## Usage
///
/// ```swift
/// let retry = RetryInterceptor(maxAttempts: 3, baseDelay: 1.0)
///
/// @API(baseURL: "https://api.example.com")
/// @Interceptors([retry])
/// protocol DataAPI {
///   @GET("/data")
///   func getData() async throws -> Data
/// }
/// ```
///
/// ## Retry Strategy
///
/// **Retryable errors:**
/// - Network errors (connection failures, timeouts)
/// - Server errors: 500-599
/// - Request timeout: 408
/// - Rate limit: 429
///
/// **Non-retryable errors:**
/// - Client errors: 400-499 (except 408, 429)
/// - Success responses: 200-399
///
/// ## Backoff Calculation
///
/// ```
/// delay = baseDelay * (2 ^ attemptNumber) + randomJitter
/// ```
///
/// Example with baseDelay=1.0:
/// - Attempt 1: ~1s
/// - Attempt 2: ~2s
/// - Attempt 3: ~4s
public struct RetryInterceptor: ResponseInterceptor, Sendable {
  /// Maximum number of retry attempts (not including original request)
  public let maxAttempts: Int

  /// Base delay in seconds for exponential backoff
  public let baseDelay: TimeInterval

  /// Maximum delay cap in seconds to prevent excessive waiting
  public let maxDelay: TimeInterval

  /// Creates a retry interceptor with exponential backoff.
  ///
  /// - Parameters:
  ///   - maxAttempts: Maximum retry attempts (default: 3)
  ///   - baseDelay: Base delay for exponential backoff in seconds (default: 1.0)
  ///   - maxDelay: Maximum delay cap in seconds (default: 60.0)
  public init(
    maxAttempts: Int = 3,
    baseDelay: TimeInterval = 1.0,
    maxDelay: TimeInterval = 60.0
  ) {
    self.maxAttempts = maxAttempts
    self.baseDelay = baseDelay
    self.maxDelay = maxDelay
  }

  // MARK: - ResponseInterceptor

  public func intercept(
    response: HTTPResponse,
    context: InterceptorContext
  ) async throws -> InterceptorResult {
    // Check if we should retry
    guard shouldRetry(response: response, context: context) else {
      return .proceed
    }

    // Check if we've exceeded max attempts
    guard context.attemptCount < maxAttempts else {
      return .proceed
    }

    // Calculate exponential backoff delay with jitter
    let delay = calculateDelay(attemptCount: context.attemptCount)

    return .retry(after: delay)
  }

  // MARK: - Retry Logic

  /// Determines if a response should be retried.
  private func shouldRetry(response: HTTPResponse, context: InterceptorContext) -> Bool {
    let statusCode = response.status.rawValue

    // Retry server errors (500-599)
    if statusCode >= 500 {
      return true
    }

    // Retry request timeout (408)
    if statusCode == 408 {
      return true
    }

    // Retry rate limit (429)
    if statusCode == 429 {
      return true
    }

    // Don't retry success or client errors
    return false
  }

  /// Calculates exponential backoff delay with jitter.
  ///
  /// Formula: baseDelay * (2 ^ attemptCount) + randomJitter
  ///
  /// Jitter is random value between 0 and 0.1 * calculated delay to prevent
  /// synchronized retries (thundering herd).
  private func calculateDelay(attemptCount: Int) -> TimeInterval {
    // Exponential backoff: baseDelay * (2 ^ attemptCount)
    let exponentialDelay = baseDelay * pow(2.0, Double(attemptCount))

    // Cap at maxDelay
    let cappedDelay = min(exponentialDelay, maxDelay)

    // Add jitter (0-10% of delay) to prevent thundering herd
    let jitter = Double.random(in: 0...(cappedDelay * 0.1))

    return cappedDelay + jitter
  }
}

// MARK: - Convenience Constructors

extension RetryInterceptor {
  /// Aggressive retry strategy with fast retries
  public static var aggressive: Self {
    Self(maxAttempts: 5, baseDelay: 0.5, maxDelay: 30.0)
  }

  /// Conservative retry strategy with slower retries
  public static var conservative: Self {
    Self(maxAttempts: 2, baseDelay: 2.0, maxDelay: 60.0)
  }

  /// Standard retry strategy (default configuration)
  public static var standard: Self {
    Self(maxAttempts: 3, baseDelay: 1.0, maxDelay: 60.0)
  }
}
