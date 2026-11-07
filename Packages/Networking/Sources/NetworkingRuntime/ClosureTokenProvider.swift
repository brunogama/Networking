import NetworkingCore

/// A token provider that uses closures for all operations.
public struct ClosureTokenProvider: AuthenticationMiddleware.TokenProvider {
  private let getCurrentHandler: @Sendable () async throws -> BearerTokenValue?
  private let refreshHandler: @Sendable () async throws -> BearerTokenValue
  private let shouldRefreshHandler: @Sendable (HTTPError) async -> AuthenticationDecision

  /// Supplies explicit credential loading, refresh, and refresh eligibility operations.
  public init(
    getCurrentToken: @escaping @Sendable () async throws -> BearerTokenValue?,
    refreshToken: @escaping @Sendable () async throws -> BearerTokenValue,
    shouldRefreshToken: @escaping @Sendable (HTTPError) async -> AuthenticationDecision = {
      error in
      if case .http(let status) = error.category, status == .unauthorized {
        return true
      }

      return false
    }
  ) {
    self.getCurrentHandler = getCurrentToken
    self.refreshHandler = refreshToken
    self.shouldRefreshHandler = shouldRefreshToken
  }

  /// Loads the credential through the configured operation.
  public func getCurrentToken() async throws -> BearerTokenValue? {
    try await getCurrentHandler()
  }

  /// Refreshes through the configured operation.
  public func refreshToken() async throws -> BearerTokenValue {
    try await refreshHandler()
  }

  /// Evaluates refresh eligibility through the configured operation.
  public func shouldRefreshToken(for error: HTTPError) async -> AuthenticationDecision {
    await shouldRefreshHandler(error)
  }
}
