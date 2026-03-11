import NetworkingCore

/// A simple token provider that stores tokens in memory.
public actor MemoryTokenProvider: AuthenticationMiddleware.TokenProvider {
  private var accessToken: BearerTokenValue?
  private let refreshHandler: @Sendable () async throws -> BearerTokenValue

  public init(
    initialToken: BearerTokenValue? = nil,
    refreshHandler: @escaping @Sendable () async throws -> BearerTokenValue
  ) {
    self.accessToken = initialToken
    self.refreshHandler = refreshHandler
  }

  public func getCurrentToken() async throws -> BearerTokenValue? {
    accessToken
  }

  public func refreshToken() async throws -> BearerTokenValue {
    let newToken = try await refreshHandler()
    accessToken = newToken
    return newToken
  }

  public func shouldRefreshToken(for error: HTTPError) async -> AuthenticationDecision {
    if case .http(let status) = error.category, status.rawValue == 401 {
      return true
    }

    return false
  }

  public func setToken(_ token: BearerTokenValue?) async {
    accessToken = token
  }
}

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

extension AuthenticationMiddleware {
  /// Creates an authentication middleware with a memory-based token provider.
  public static func withMemoryProvider(
    client: any HTTPClient,
    initialToken: BearerTokenValue? = nil,
    refreshHandler: @escaping @Sendable () async throws -> BearerTokenValue
  ) -> AuthenticationMiddleware {
    AuthenticationMiddleware(
      configuration: Configuration(),
      tokenProvider: MemoryTokenProvider(
        initialToken: initialToken,
        refreshHandler: refreshHandler
      ),
      client: client
    )
  }

  /// Creates an authentication middleware with a closure-based token provider.
  public static func withClosureProvider(
    client: any HTTPClient,
    getCurrentToken: @escaping @Sendable () async throws -> BearerTokenValue?,
    refreshToken: @escaping @Sendable () async throws -> BearerTokenValue
  ) -> AuthenticationMiddleware {
    AuthenticationMiddleware(
      configuration: Configuration(),
      tokenProvider: ClosureTokenProvider(
        getCurrentToken: getCurrentToken,
        refreshToken: refreshToken
      ),
      client: client
    )
  }
}
