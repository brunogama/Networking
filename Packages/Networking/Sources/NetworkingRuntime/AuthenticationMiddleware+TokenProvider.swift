import NetworkingCore

extension AuthenticationMiddleware {
  // MARK: - Token Provider Protocol

  /// Protocol for providing authentication tokens.
  public protocol TokenProvider: Sendable {
    /// Returns the current access token.
    func getCurrentToken() async throws -> BearerTokenValue?

    /// Refreshes the access token and returns the new token.
    func refreshToken() async throws -> BearerTokenValue

    /// Determines if a token refresh should be attempted for the given error.
    func shouldRefreshToken(for error: HTTPError) async -> AuthenticationDecision
  }
}
