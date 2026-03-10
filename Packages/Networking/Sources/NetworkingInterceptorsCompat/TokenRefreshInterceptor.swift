import NetworkingRuntime
import Foundation

/// Response interceptor that automatically refreshes expired tokens and retries failed requests.
///
/// Detects 401 Unauthorized responses, refreshes the access token using a provided refresh handler,
/// and retries the original request with the new token. Prevents concurrent refresh operations
/// using actor-based synchronization.
///
/// ## Usage
///
/// ```swift
/// let refreshInterceptor = TokenRefreshInterceptor { refreshToken in
///   // Call your token refresh endpoint
///   let response = try await api.refreshToken(refreshToken)
///   return (response.accessToken, response.refreshToken)
/// }
///
/// @API(baseURL: "https://api.example.com")
/// @Interceptors([refreshInterceptor])
/// protocol UserAPI {
///   @GET("/profile")
///   func getProfile() async throws -> UserProfile
/// }
/// ```
@available(
  *,
  deprecated,
  message: """
    TokenRefreshInterceptor is a compatibility API. \
    Prefer authentication middleware or custom response/error middleware for new runtime behavior.
    """
)
public struct TokenRefreshInterceptor: ResponseInterceptor, Sendable {
  /// Handler that refreshes tokens and returns new access and refresh tokens
  public typealias RefreshHandler =
    @Sendable (RefreshTokenValue) async throws -> (
      accessToken: BearerTokenValue, refreshToken: RefreshTokenValue
    )

  /// Handler that updates tokens in persistent storage
  public typealias TokenUpdateHandler =
    @Sendable (BearerTokenValue, RefreshTokenValue) async -> Void

  private let refreshHandler: RefreshHandler
  private let tokenUpdateHandler: TokenUpdateHandler
  private let refreshCoordinator: RefreshCoordinator

  /// Creates a token refresh interceptor.
  ///
  /// - Parameters:
  ///   - refreshHandler: Async closure that refreshes tokens. Returns new access and refresh tokens.
  ///   - tokenUpdateHandler: Async closure that updates tokens in storage (e.g., Keychain).
  public init(
    refreshHandler: @escaping RefreshHandler,
    tokenUpdateHandler: @escaping TokenUpdateHandler
  ) {
    self.refreshHandler = refreshHandler
    self.tokenUpdateHandler = tokenUpdateHandler
    self.refreshCoordinator = RefreshCoordinator()
  }

  package init(
    refreshHandler:
      @escaping @Sendable (String) async throws -> (
        accessToken: String, refreshToken: String
      ),
    tokenUpdateHandler: @escaping @Sendable (String, String) async -> Void
  ) {
    self.refreshHandler = { refreshToken in
      let tokens = try await refreshHandler(refreshToken.rawValue)
      return (
        accessToken: BearerTokenValue(tokens.accessToken),
        refreshToken: RefreshTokenValue(tokens.refreshToken)
      )
    }
    self.tokenUpdateHandler = { accessToken, refreshToken in
      await tokenUpdateHandler(accessToken.rawValue, refreshToken.rawValue)
    }
    self.refreshCoordinator = RefreshCoordinator()
  }

  // MARK: - ResponseInterceptor

  public func intercept(
    response: HTTPResponse,
    context: InterceptorContext
  ) async throws -> InterceptorResult {
    // Only handle 401 Unauthorized responses
    guard response.status.rawValue == 401 else {
      return .proceed
    }

    // Extract current refresh token from context metadata
    guard let refreshToken = context.metadata["refreshToken"]?.stringValue else {
      // No refresh token available, cannot refresh
      return .proceed
    }
    let refreshTokenValue = RefreshTokenValue(refreshToken.rawValue)

    do {
      // Coordinate refresh to prevent concurrent refresh operations
      let newTokens = try await refreshCoordinator.refresh(using: refreshTokenValue) {
        try await refreshHandler(refreshTokenValue)
      }

      // Update tokens in persistent storage
      await tokenUpdateHandler(newTokens.accessToken, newTokens.refreshToken)

      // Retry the original request with new token
      // Note: The new token should be picked up by AuthenticationInterceptor
      // via the tokenUpdateHandler updating the token source
      return .retry(after: RetryDelay(0))
    } catch {
      // Refresh failed, propagate error
      return .proceed
    }
  }
}

/// Actor that coordinates token refresh operations to prevent concurrent refreshes.
private actor RefreshCoordinator {
  private var refreshTask:
    Task<
      (accessToken: BearerTokenValue, refreshToken: RefreshTokenValue),
      Error
    >?

  /// Ensures only one refresh operation occurs at a time.
  ///
  /// If a refresh is already in progress, awaits the existing task.
  /// Otherwise, starts a new refresh operation.
  func refresh(
    using refreshToken: RefreshTokenValue,
    operation:
      @escaping @Sendable () async throws -> (
        accessToken: BearerTokenValue, refreshToken: RefreshTokenValue
      )
  ) async throws -> (accessToken: BearerTokenValue, refreshToken: RefreshTokenValue) {
    // If refresh is already in progress, await it
    if let existingTask = refreshTask {
      return try await existingTask.value
    }

    // Start new refresh operation
    let task = Task {
      try await operation()
    }

    refreshTask = task

    do {
      let result = try await task.value
      refreshTask = nil
      return result
    } catch {
      refreshTask = nil
      throw error
    }
  }
}
