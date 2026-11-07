import NetworkingCore

#if canImport(Security)
/// A token provider that uses Keychain for secure storage.
public final class KeychainTokenProvider: AuthenticationMiddleware.TokenProvider {

  public typealias RefreshHandler =
    @Sendable (RefreshTokenValue) async throws -> BearerTokenValue

  private let keychainService: KeychainService
  private let tokenKey: KeychainItemKey
  private let refreshTokenKey: KeychainItemKey?
  private let refreshHandler: RefreshHandler?

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

  public func getCurrentToken() async throws -> BearerTokenValue? {
    try await keychainService.retrieveString(forKey: tokenKey).map {
      BearerTokenValue($0.rawValue)
    }
  }

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

  public func storeToken(_ token: BearerTokenValue) async throws {
    try await keychainService.store(KeychainStringValue(token.rawValue), forKey: tokenKey)
  }

  public func storeRefreshToken(_ token: RefreshTokenValue) async throws {
    guard let refreshTokenKey else {
      throw HTTPError(category: .configuration("Refresh token key not configured"))
    }

    try await keychainService.store(
      KeychainStringValue(token.rawValue),
      forKey: refreshTokenKey
    )
  }

  public func clearTokens() async throws {
    try await keychainService.deleteTokens(tokenKey: tokenKey, refreshKey: refreshTokenKey)
  }

  private func missingRefreshTokenError() -> HTTPError {
    HTTPError(category: .configuration("No refresh token available"))
  }
}

extension KeychainTokenProvider {

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
