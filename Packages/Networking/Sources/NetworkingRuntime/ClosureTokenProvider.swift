import NetworkingCore

/// A token provider that uses closures for all operations.
public struct ClosureTokenProvider: AuthenticationMiddleware.TokenProvider {
  private let getCurrentHandler: @Sendable () async throws -> BearerTokenValue?
  private let refreshHandler: @Sendable () async throws -> BearerTokenValue
  private let shouldRefreshHandler: @Sendable (HTTPError) async -> AuthenticationDecision

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

  public func getCurrentToken() async throws -> BearerTokenValue? {
    try await getCurrentHandler()
  }

  public func refreshToken() async throws -> BearerTokenValue {
    try await refreshHandler()
  }

  public func shouldRefreshToken(for error: HTTPError) async -> AuthenticationDecision {
    await shouldRefreshHandler(error)
  }
}
