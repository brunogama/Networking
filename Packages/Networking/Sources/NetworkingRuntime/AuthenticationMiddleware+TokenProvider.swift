import NetworkingCore

extension AuthenticationMiddleware {
  // MARK: - Token Provider Protocol

  /// Protocol for providing authentication tokens.
  public protocol TokenProvider: Sendable {

    func getCurrentToken() async throws -> BearerTokenValue?

    func refreshToken() async throws -> BearerTokenValue

    func shouldRefreshToken(for error: HTTPError) async -> AuthenticationDecision
  }
}
