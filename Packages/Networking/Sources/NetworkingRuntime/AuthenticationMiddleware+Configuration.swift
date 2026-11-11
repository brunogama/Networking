import NetworkingCore

extension AuthenticationMiddleware {
  // MARK: - Configuration

  /// Configuration for authentication middleware.
  public struct Configuration: Sendable {

    public let authorizationHeaderName: HTTPHeaderName

    public let tokenPrefix: AuthorizationTokenPrefix

    public let maxRefreshAttempts: RetryAttemptCount

    public let shouldAuthenticate: @Sendable (HTTPRequest) -> AuthenticationDecision

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
