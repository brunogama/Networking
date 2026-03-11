import NetworkingCore

#if canImport(Security)
/// A token provider that uses Keychain for secure storage.
public final class KeychainTokenProvider: BearerTokenProvider {
  private let keychainService: KeychainService
  private let tokenKey: KeychainItemKey
  private let refreshTokenKey: KeychainItemKey?

  public init(
    keychainService: KeychainService,
    tokenKey: KeychainItemKey = "access_token",
    refreshTokenKey: KeychainItemKey? = "refresh_token"
  ) {
    self.keychainService = keychainService
    self.tokenKey = tokenKey
    self.refreshTokenKey = refreshTokenKey
  }

  /// Convenience initializer with service name.
  public convenience init(
    service: KeychainServiceName,
    tokenKey: KeychainItemKey = "access_token",
    refreshTokenKey: KeychainItemKey? = "refresh_token"
  ) {
    self.init(
      keychainService: KeychainService(service: service),
      tokenKey: tokenKey,
      refreshTokenKey: refreshTokenKey
    )
  }

  public func getCurrentToken() async throws -> BearerTokenValue? {
    try await keychainService.retrieveString(forKey: tokenKey).map {
      BearerTokenValue($0.rawValue)
    }
  }

  public func refreshToken() async throws -> BearerTokenValue {
    guard let refreshTokenKey else {
      throw missingRefreshTokenError()
    }

    guard try await keychainService.retrieveString(forKey: refreshTokenKey) != nil else {
      throw missingRefreshTokenError()
    }

    throw HTTPError(category: .configuration("Token refresh not implemented"))
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

  /// Clears all stored tokens.
  public func clearTokens() async throws {
    try await keychainService.delete(tokenKey)

    if let refreshTokenKey {
      try await keychainService.delete(refreshTokenKey)
    }
  }

  private func missingRefreshTokenError() -> HTTPError {
    HTTPError(category: .configuration("No refresh token available"))
  }
}

extension KeychainTokenProvider {
  /// Factory method to create a token provider for OAuth2 flows.
  public static func oauth2(
    service: KeychainServiceName,
    clientId: OAuthClientIdentifier? = nil
  ) -> KeychainTokenProvider {
    let tokenKey = oauthTokenKey(clientId: clientId, suffix: "access_token")
    let refreshKey = oauthTokenKey(clientId: clientId, suffix: "refresh_token")

    return KeychainTokenProvider(
      service: service,
      tokenKey: tokenKey,
      refreshTokenKey: refreshKey
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
