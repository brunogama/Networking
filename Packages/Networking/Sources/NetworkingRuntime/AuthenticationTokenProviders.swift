import Foundation
import NetworkingCore

extension AuthenticationMiddleware.TokenProvider {
  /// Refreshes bearer credentials only after an unauthorized response by default.
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

  /// Creates an in-memory credential store and its refresh operation.
  public init(
    initialToken: BearerTokenValue? = nil,
    refreshHandler: @escaping @Sendable () async throws -> BearerTokenValue
  ) {
    self.accessToken = initialToken
    self.refreshHandler = refreshHandler
  }

  /// Returns the current credential.
  public func getCurrentToken() async throws -> BearerTokenValue? {
    accessToken
  }

  /// Refreshes the credential unless another mutation supersedes the operation while suspended.
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

  /// Allows refresh after an unauthorized response.
  public func shouldRefreshToken(for error: HTTPError) async -> AuthenticationDecision {
    if case .http(let status) = error.category, status.rawValue == 401 {
      return true
    }

    return false
  }

  /// Replaces the credential; nil represents a signed-out state.
  public func setToken(_ token: BearerTokenValue?) async {
    credentialRevision = UUID()
    accessToken = token
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
