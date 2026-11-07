import NetworkingCore

extension AuthenticationMiddleware {
  // MARK: - Configuration

  /// Configuration for authentication middleware.
  public struct Configuration: Sendable {
    /// The header name for the authorization token.
    public let authorizationHeaderName: HTTPHeaderName

    /// The token prefix, such as the bearer scheme followed by a space.
    public let tokenPrefix: AuthorizationTokenPrefix

    /// Maximum number of refresh attempts.
    public let maxRefreshAttempts: RetryAttemptCount

    /// Predicate to determine if authentication should be applied to a request.
    public let shouldAuthenticate: @Sendable (HTTPRequest) -> AuthenticationDecision

    /// Configures bearer injection and the maximum number of refresh-and-retry attempts.
    public init(
      authorizationHeaderName: HTTPHeaderName = "Authorization",
      tokenPrefix: AuthorizationTokenPrefix = "Bearer ",
      maxRefreshAttempts: RetryAttemptCount = 1,
      shouldAuthenticate: @escaping @Sendable (HTTPRequest) -> AuthenticationDecision = { _ in
        true
      }
    ) {
      self.authorizationHeaderName = authorizationHeaderName
      self.tokenPrefix = tokenPrefix
      self.maxRefreshAttempts = maxRefreshAttempts
      self.shouldAuthenticate = shouldAuthenticate
    }
  }
}
