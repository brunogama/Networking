import NetworkingRuntime
import Foundation

/// Request interceptor that adds authentication headers to requests.
///
/// Supports Bearer token authentication by adding the `Authorization` header
/// with a token provided by a token provider closure.
///
/// ## Usage
///
/// ```swift
/// let authInterceptor = AuthenticationInterceptor { () async throws -> String in
///   return try await authService.getAccessToken()
/// }
///
/// @API(baseURL: "https://api.example.com")
/// @Interceptors([authInterceptor])
/// protocol SecureAPI {
///   @GET("/user/profile")
///   func getProfile() async throws -> Profile
/// }
/// ```
@available(
  *,
  deprecated,
  message: """
    AuthenticationInterceptor is a compatibility API.
    Prefer AuthenticationMiddleware or a custom HTTPRequestMiddleware.
    """
)
public struct AuthenticationInterceptor: RequestInterceptor, Sendable {
  /// Token provider that returns the current access token
  private let tokenProvider: @Sendable () async throws -> BearerTokenValue

  /// Creates an authentication interceptor with a token provider.
  ///
  /// - Parameter tokenProvider: Async closure that returns the current access token
  public init(tokenProvider: @escaping @Sendable () async throws -> BearerTokenValue) {
    self.tokenProvider = tokenProvider
  }

  package init(tokenProvider: @escaping @Sendable () async throws -> String) {
    self.tokenProvider = { BearerTokenValue(try await tokenProvider()) }
  }

  /// Intercepts the request and adds the Authorization header with a Bearer token.
  ///
  /// - Parameters:
  ///   - request: The HTTP request to modify
  ///   - context: Execution context for the request
  /// - Returns: `.proceed` to continue the request chain
  /// - Throws: If the token provider fails to return a token
  public func intercept(
    request: inout HTTPRequest,
    context: InterceptorContext
  ) async throws -> InterceptorResult {
    let token = try await tokenProvider()
    request.addHeader(name: "Authorization", value: "Bearer \(token)")
    return .proceed
  }
}

/// Convenience extension for creating auth interceptors with static tokens
@available(
  *,
  deprecated,
  message: """
    AuthenticationInterceptor is a compatibility API.
    Prefer AuthenticationMiddleware or a custom HTTPRequestMiddleware.
    """
)
extension AuthenticationInterceptor {
  /// Creates an authentication interceptor with a static token.
  ///
  /// Use this for testing or when the token doesn't change during the app lifetime.
  ///
  /// - Parameter token: The static Bearer token
  /// - Returns: Configured authentication interceptor
  public static func bearer(_ token: BearerTokenValue) -> Self {
    Self { token }
  }
}
