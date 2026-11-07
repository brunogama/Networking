import Foundation
import NetworkingCore

extension AuthenticationMiddleware.TokenProvider {

  public func shouldRefreshToken(for error: HTTPError) async -> AuthenticationDecision {
    if case .http(.unauthorized) = error.category { return true }
    return false
  }
}

/// A simple token provider that stores tokens in memory.
public actor MemoryTokenProvider: AuthenticationMiddleware.TokenProvider {
  private var accessToken: BearerTokenValue?
  private var credentialRevision = UUID()
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
    try Task.checkCancellation()
    let revision = credentialRevision
    let newToken = try await refreshHandler()
    try Task.checkCancellation()
    guard revision == credentialRevision else {
      throw HTTPError(category: .custom("Authentication", "Credentials changed during refresh"))
    }
    accessToken = newToken
    credentialRevision = UUID()
    return newToken
  }

  public func shouldRefreshToken(for error: HTTPError) async -> AuthenticationDecision {
    if case .http(let status) = error.category, status.rawValue == 401 {
      return true
    }

    return false
  }

  public func setToken(_ token: BearerTokenValue?) async {
    credentialRevision = UUID()
    accessToken = token
  }
}

extension AuthenticationMiddleware {

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
