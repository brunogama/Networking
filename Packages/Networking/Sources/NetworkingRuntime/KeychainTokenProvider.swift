import NetworkingCore

#if canImport(Security)
/// A token provider that uses Keychain for secure storage.
public final class KeychainTokenProvider: AuthenticationMiddleware.TokenProvider {
  /// Exchanges a refresh credential for an access credential.
  public typealias RefreshHandler =
    @Sendable (RefreshTokenValue) async throws -> BearerTokenValue

  private let keychainService: KeychainService
  private let tokenKey: KeychainItemKey
  private let refreshTokenKey: KeychainItemKey?
  private let refreshHandler: RefreshHandler?

  /// Reuses a keychain service without retaining credential values between reads.
  public init(
    keychainService: KeychainService,
    tokenKey: KeychainItemKey = "access_token",
    refreshTokenKey: KeychainItemKey? = "refresh_token",
    refreshHandler: RefreshHandler? = nil
  ) {
    self.keychainService = keychainService
    self.tokenKey = tokenKey
    self.refreshTokenKey = refreshTokenKey
    self.refreshHandler = refreshHandler
  }

  /// Convenience initializer with service name.
  public convenience init(
    service: KeychainServiceName,
    tokenKey: KeychainItemKey = "access_token",
    refreshTokenKey: KeychainItemKey? = "refresh_token",
    refreshHandler: RefreshHandler? = nil
  ) {
    self.init(
      keychainService: KeychainService(service: service),
      tokenKey: tokenKey,
      refreshTokenKey: refreshTokenKey,
      refreshHandler: refreshHandler
    )
  }

  /// Reads the current access credential directly from the keychain.
  public func getCurrentToken() async throws -> BearerTokenValue? {
    try await keychainService.retrieveString(forKey: tokenKey).map {
      BearerTokenValue($0.rawValue)
    }
  }

  /// Exchanges the stored refresh credential and persists it only while credentials are unchanged.
  ///
  /// Mutations through the shared keychain service invalidate the pending refresh.
  public func refreshToken() async throws -> BearerTokenValue {
    try Task.checkCancellation()
    guard let refreshTokenKey else {
      throw missingRefreshTokenError()
    }

    guard
      let snapshot = try await keychainService.refreshCredential(
        tokenKey: tokenKey,
        refreshKey: refreshTokenKey
      )
    else {
      throw missingRefreshTokenError()
    }

    guard let refreshHandler else {
      throw HTTPError(category: .configuration("A token refresh handler is required"))
    }

    let token = try await refreshHandler(RefreshTokenValue(snapshot.refreshToken.rawValue))
    try await keychainService.storeRefreshedToken(token, matching: snapshot)
    return token
  }

  /// Stores an access token securely in the keychain.
  public func storeToken(_ token: BearerTokenValue) async throws {
    try await keychainService.store(KeychainStringValue(token.rawValue), forKey: tokenKey)
  }

  /// Stores a refresh token securely in the keychain.
  public func storeRefreshToken(_ token: RefreshTokenValue) async throws {
    guard let refreshTokenKey else {
      throw HTTPError(category: .configuration("Refresh token key not configured"))
    }

    try await keychainService.store(
      KeychainStringValue(token.rawValue),
      forKey: refreshTokenKey
    )
  }

  /// Deletes both credentials in one actor turn and invalidates pending refreshes.
  ///
  /// Keychain failures are propagated; this operation is not a system-wide storage transaction.
  public func clearTokens() async throws {
    try await keychainService.deleteTokens(tokenKey: tokenKey, refreshKey: refreshTokenKey)
  }

  private func missingRefreshTokenError() -> HTTPError {
    HTTPError(category: .configuration("No refresh token available"))
  }
}

extension KeychainTokenProvider {
  /// Factory method to create a token provider for OAuth2 flows.
  public static func oauth2(
    service: KeychainServiceName,
    clientId: OAuthClientIdentifier? = nil,
    refreshHandler: RefreshHandler? = nil
  ) -> KeychainTokenProvider {
    let tokenKey = oauthTokenKey(clientId: clientId, suffix: "access_token")
    let refreshKey = oauthTokenKey(clientId: clientId, suffix: "refresh_token")

    return KeychainTokenProvider(
      service: service,
      tokenKey: tokenKey,
      refreshTokenKey: refreshKey,
      refreshHandler: refreshHandler
    )
  }

  /// Factory method to create a token provider for API key authentication.
  public static func apiKey(
    service: KeychainServiceName,
    keyName: KeychainItemKey = "api_key"
  ) -> KeychainTokenProvider {
    KeychainTokenProvider(
      service: service,
      tokenKey: keyName,
      refreshTokenKey: nil
    )
  }

  private static func oauthTokenKey(
    clientId: OAuthClientIdentifier?,
    suffix: String
  ) -> KeychainItemKey {
    guard let clientId else {
      return KeychainItemKey(suffix)
    }

    return KeychainItemKey("\(clientId.rawValue)_\(suffix)")
  }
}
#endif
