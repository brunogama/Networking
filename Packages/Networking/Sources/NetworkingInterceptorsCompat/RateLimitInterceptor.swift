import NetworkingRuntime
import Foundation

/// Request interceptor that enforces rate limiting to prevent excessive API requests.
///
/// Tracks request rates per endpoint and enforces configurable limits using a sliding
/// window algorithm. When limits are exceeded, requests are either delayed or rejected
/// based on the configured strategy.
///
/// ## Usage
///
/// ```swift
/// let rateLimit = RateLimitInterceptor(
///   requestsPerWindow: 100,
///   windowDuration: 60.0  // 100 requests per minute
/// )
///
/// @API(baseURL: "https://api.example.com")
/// @Interceptors([rateLimit])
/// protocol DataAPI {
///   @GET("/data")
///   func getData() async throws -> Data
/// }
/// ```
///
/// ## Rate Limiting Strategy
///
/// **Sliding Window Algorithm:**
/// - Tracks timestamps of recent requests
/// - Removes expired requests outside the time window
/// - Allows up to N requests within the window duration
///
/// **Behavior:**
/// - Under limit: Request proceeds immediately
/// - At limit: Request is delayed until window allows
/// - Strategy determines delay vs rejection
///
/// ## Per-Endpoint Tracking
///
/// Rate limits are tracked separately for each endpoint path:
/// ```
/// /api/users -> 50 requests/minute
/// /api/posts -> 50 requests/minute
/// ```
@available(
  *,
  deprecated,
  message:
    "RateLimitInterceptor is a compatibility API. Prefer middleware-based rate limiting for new runtime behavior."
)
public struct RateLimitInterceptor: RequestInterceptor, Sendable {
  /// Maximum number of requests allowed per window
  public let requestsPerWindow: Int

  /// Duration of the rate limit window in seconds
  public let windowDuration: TimeInterval

  /// Strategy for handling rate limit exceeded
  public let strategy: RateLimitStrategy

  /// Thread-safe rate limiter actor
  private let limiter: RateLimiter

  /// Strategy for handling rate limit exceeded
  public enum RateLimitStrategy: Sendable {
    /// Delay the request until the window allows it
    case delay

    /// Reject the request immediately with an error
    case reject
  }

  /// Creates a rate limit interceptor.
  ///
  /// - Parameters:
  ///   - requestsPerWindow: Maximum requests allowed per window (default: 100)
  ///   - windowDuration: Window duration in seconds (default: 60)
  ///   - strategy: Strategy for handling exceeded limits (default: .delay)
  public init(
    requestsPerWindow: Int = 100,
    windowDuration: TimeInterval = 60.0,
    strategy: RateLimitStrategy = .delay
  ) {
    self.requestsPerWindow = requestsPerWindow
    self.windowDuration = windowDuration
    self.strategy = strategy
    self.limiter = RateLimiter(
      requestsPerWindow: requestsPerWindow,
      windowDuration: windowDuration
    )
  }

  // MARK: - RequestInterceptor

  public func intercept(
    request: inout HTTPRequest,
    context: InterceptorContext
  ) async throws -> InterceptorResult {
    // Check if we can proceed with this request
    let canProceed = await limiter.checkAndRecord(path: context.path)

    if canProceed {
      return .proceed
    }

    // Rate limit exceeded - apply strategy
    switch strategy {
    case .delay:
      // Calculate delay until window allows
      let delay = await limiter.calculateDelay(path: context.path)
      return .retry(after: delay)

    case .reject:
      // Reject immediately
      throw InterceptorError.rateLimitExceeded(
        path: context.path,
        limit: requestsPerWindow,
        window: windowDuration
      )
    }
  }

  // MARK: - Management

  /// Clears rate limit history for all endpoints.
  public func reset() async {
    await limiter.reset()
  }

  /// Clears rate limit history for a specific endpoint.
  public func reset(path: String) async {
    await limiter.reset(path: path)
  }
}

// MARK: - Rate Limiter Actor

/// Thread-safe rate limiter using sliding window algorithm.
private actor RateLimiter {
  private let requestsPerWindow: Int
  private let windowDuration: TimeInterval

  /// Tracks request timestamps per endpoint path
  private var requestHistory: [String: [Date]] = [:]

  init(requestsPerWindow: Int, windowDuration: TimeInterval) {
    self.requestsPerWindow = requestsPerWindow
    self.windowDuration = windowDuration
  }

  /// Checks if request is allowed and records it if so.
  ///
  /// - Parameter path: The request endpoint path
  /// - Returns: True if request is allowed, false if rate limited
  func checkAndRecord(path: String) -> Bool {
    let now = Date()
    let windowStart = now.addingTimeInterval(-windowDuration)

    // Get or create history for this path
    var history = requestHistory[path] ?? []

    // Remove expired requests outside the window
    history.removeAll { $0 < windowStart }

    // Check if we're under the limit
    guard history.count < requestsPerWindow else {
      // Update history (remove expired but don't record new)
      requestHistory[path] = history
      return false
    }

    // Record this request and proceed
    history.append(now)
    requestHistory[path] = history
    return true
  }

  /// Calculates delay until the window allows another request.
  ///
  /// - Parameter path: The request endpoint path
  /// - Returns: Delay in seconds until next request is allowed
  func calculateDelay(path: String) -> TimeInterval {
    let now = Date()
    let windowStart = now.addingTimeInterval(-windowDuration)

    // Get history for this path
    var history = requestHistory[path] ?? []

    // Remove expired requests
    history.removeAll { $0 < windowStart }

    // If we have room now, no delay needed
    guard history.count >= requestsPerWindow else {
      return 0
    }

    // Find the oldest request in the window
    guard let oldestRequest = history.first else {
      return 0
    }

    // Calculate when the oldest request will expire
    let oldestExpiration = oldestRequest.addingTimeInterval(windowDuration)
    let delay = oldestExpiration.timeIntervalSince(now)

    return max(0, delay)
  }

  /// Resets all rate limit history.
  func reset() {
    requestHistory.removeAll()
  }

  /// Resets rate limit history for a specific path.
  func reset(path: String) {
    requestHistory.removeValue(forKey: path)
  }
}

// MARK: - Convenience Constructors

@available(
  *,
  deprecated,
  message:
    "RateLimitInterceptor is a compatibility API. Prefer middleware-based rate limiting for new runtime behavior."
)
extension RateLimitInterceptor {
  /// Strict rate limiting (60 requests/minute, reject on exceed)
  public static var strict: Self {
    Self(requestsPerWindow: 60, windowDuration: 60.0, strategy: .reject)
  }

  /// Lenient rate limiting (100 requests/minute, delay on exceed)
  public static var lenient: Self {
    Self(requestsPerWindow: 100, windowDuration: 60.0, strategy: .delay)
  }

  /// Per-second rate limiting (10 requests/second)
  public static var perSecond: Self {
    Self(requestsPerWindow: 10, windowDuration: 1.0, strategy: .delay)
  }
}
