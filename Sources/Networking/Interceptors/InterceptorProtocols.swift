import Foundation

/// Protocol for intercepting HTTP requests before they are sent to the network.
///
/// Request interceptors allow you to inspect and modify HTTP requests before they are executed.
/// Common use cases include:
/// - Adding authentication headers
/// - Logging outbound requests
/// - Modifying query parameters
/// - Short-circuiting requests with cached responses
///
/// ## Example: Authentication Interceptor
///
/// ```swift
/// struct AuthenticationInterceptor: RequestInterceptor {
///   private let tokenProvider: TokenProvider
///
///   func intercept(
///     request: inout HTTPRequest,
///     context: InterceptorContext
///   ) async throws -> InterceptorResult {
///     guard let token = await tokenProvider.getToken() else {
///       throw AuthError.noToken
///     }
///     request.addHeader(name: "Authorization", value: "Bearer \(token)")
///     return .proceed
///   }
/// }
/// ```
///
/// ## Example: Caching Interceptor
///
/// ```swift
/// struct CachingInterceptor: RequestInterceptor {
///   private let cache: ResponseCache
///
///   func intercept(
///     request: inout HTTPRequest,
///     context: InterceptorContext
///   ) async throws -> InterceptorResult {
///     // Only cache GET requests
///     guard context.method == .GET else { return .proceed }
///
///     if let cachedResponse = cache.get(context.path) {
///       return .shortCircuit(cachedResponse)
///     }
///     return .proceed
///   }
/// }
/// ```
///
/// - Note: All request interceptors must be `Sendable` for Swift 6 strict concurrency compliance.
/// - Important: Interceptors execute in registration order. Earlier interceptors can affect later ones.
public protocol RequestInterceptor: Sendable {
  /// Intercepts an HTTP request before it is sent to the network.
  ///
  /// - Parameters:
  ///   - request: The mutable HTTP request that can be modified by the interceptor.
  ///   - context: Contextual information about the request (path, method, attempt count).
  /// - Returns: An `InterceptorResult` indicating how to proceed:
  ///   - `.proceed`: Continue to the next interceptor or network call
  ///   - `.shortCircuit(response)`: Skip the network call and use the provided response
  ///   - `.retry(after:)`: Not applicable for request interceptors (use in response interceptors)
  /// - Throws: Any error encountered during interception (wrapped in `InterceptorError`)
  func intercept(
    request: inout HTTPRequest,
    context: InterceptorContext
  ) async throws -> InterceptorResult
}

/// Protocol for intercepting HTTP responses after they are received from the network.
///
/// Response interceptors allow you to inspect responses and trigger retries or replacements.
/// Common use cases include:
/// - Logging received responses
/// - Detecting authentication failures and refreshing tokens
/// - Triggering retries on transient errors
/// - Caching successful responses
///
/// ## Example: Token Refresh Interceptor
///
/// ```swift
/// struct TokenRefreshInterceptor: ResponseInterceptor {
///   private let tokenProvider: TokenProvider
///
///   func intercept(
///     response: HTTPResponse,
///     context: InterceptorContext
///   ) async throws -> InterceptorResult {
///     // Detect 401 Unauthorized
///     guard response.statusCode == 401 else { return .proceed }
///
///     // Refresh token
///     try await tokenProvider.refreshToken()
///
///     // Retry the original request with new token
///     return .retry(after: nil)
///   }
/// }
/// ```
///
/// ## Example: Logging Interceptor
///
/// ```swift
/// struct LoggingInterceptor: ResponseInterceptor {
///   func intercept(
///     response: HTTPResponse,
///     context: InterceptorContext
///   ) async throws -> InterceptorResult {
///     print("[\(context.method)] \(context.path) -> \(response.statusCode)")
///     print("Response headers: \(response.headers)")
///     return .proceed
///   }
/// }
/// ```
///
/// - Note: All response interceptors must be `Sendable` for Swift 6 strict concurrency compliance.
/// - Important: Interceptors execute in registration order. Earlier interceptors can affect later ones.
/// - Warning: Returning `.retry()` will increment the attempt count. Ensure you check `context.attemptCount`
///   to avoid infinite retry loops.
public protocol ResponseInterceptor: Sendable {
  /// Intercepts an HTTP response after it is received from the network.
  ///
  /// - Parameters:
  ///   - response: The HTTP response received from the network.
  ///   - context: Contextual information about the request (path, method, attempt count).
  /// - Returns: An `InterceptorResult` indicating how to proceed:
  ///   - `.proceed`: Continue to the next interceptor or decode the response
  ///   - `.shortCircuit(response)`: Replace the network response with the provided response
  ///   - `.retry(after:)`: Retry the request after an optional delay
  /// - Throws: Any error encountered during interception (wrapped in `InterceptorError`)
  func intercept(
    response: HTTPResponse,
    context: InterceptorContext
  ) async throws -> InterceptorResult
}
