import NetworkingRuntime
import Foundation

/// The result of an interceptor's execution, indicating how the interceptor chain should proceed.
///
/// Interceptors return an `InterceptorResult` to control the flow of request/response processing.
/// This allows interceptors to:
/// - Continue normal processing (`.proceed`)
/// - Skip the network call and use a cached response (`.shortCircuit`)
/// - Retry the request after refreshing tokens or backing off (`.retry`)
///
/// ## Example: Cache Short-Circuit
///
/// ```swift
/// struct CachingInterceptor: RequestInterceptor {
///   func intercept(
///     request: inout HTTPRequest,
///     context: InterceptorContext
///   ) async throws -> InterceptorResult {
///     if let cached = cache.get(context.path) {
///       return .shortCircuit(cached)  // Skip network call
///     }
///     return .proceed  // Continue to network
///   }
/// }
/// ```
///
/// ## Example: Retry After Token Refresh
///
/// ```swift
/// struct TokenRefreshInterceptor: ResponseInterceptor {
///   func intercept(
///     response: HTTPResponse,
///     context: InterceptorContext
///   ) async throws -> InterceptorResult {
///     guard response.status.rawValue == 401 else {
///       return .proceed
///     }
///
///     try await refreshToken()
///     return .retry(after: nil)  // Retry immediately with new token
///   }
/// }
/// ```
///
/// ## Example: Retry with Exponential Backoff
///
/// ```swift
/// struct RetryInterceptor: ResponseInterceptor {
///   func intercept(
///     response: HTTPResponse,
///     context: InterceptorContext
///   ) async throws -> InterceptorResult {
///     guard response.status.rawValue >= 500 else {
///       return .proceed
///     }
///
///     let delay = pow(2.0, Double(context.attemptCount))
///     return .retry(after: delay)  // Retry with exponential backoff
///   }
/// }
/// ```
@available(
  *,
  deprecated,
  message: """
    InterceptorResult is part of the compatibility interceptor layer. \
    Prefer middleware return values and HTTPError propagation for new runtime behavior.
    """
)
public enum InterceptorResult: Sendable {
  /// Continue to the next interceptor or proceed with the network call/response processing.
  ///
  /// This is the default case when an interceptor doesn't need to alter the normal flow.
  /// For request interceptors, this continues to the next request interceptor or makes the network call.
  /// For response interceptors, this continues to the next response interceptor or completes processing.
  case proceed

  /// Skip the network call and use the provided response instead.
  ///
  /// This is typically used by caching interceptors to return cached data without
  /// making a network request, or by mock interceptors in testing scenarios.
  ///
  /// - Parameter response: The HTTP response to use instead of making a network call
  ///
  /// - Important: Only request interceptors should return `.shortCircuit`.
  ///   Response interceptors can technically return this, but it will replace the network response.
  case shortCircuit(HTTPResponse)

  /// Retry the request after an optional delay.
  ///
  /// This is typically used by response interceptors to retry failed requests after:
  /// - Refreshing authentication tokens (retry immediately)
  /// - Backing off from rate limits (retry after delay)
  /// - Recovering from transient errors (retry with exponential backoff)
  ///
  /// - Parameter after: Optional duration (in seconds) to wait before retrying.
  ///   If `nil`, the retry happens immediately.
  ///
  /// - Important: The `attemptCount` in `InterceptorContext` will be incremented
  ///   on each retry. Always check this value to avoid infinite retry loops.
  ///
  /// - Warning: Returning `.retry()` from a request interceptor is unusual and may
  ///   cause unexpected behavior. Retry logic should typically be in response interceptors.
  case retry(after: RetryDelay? = nil)
}
