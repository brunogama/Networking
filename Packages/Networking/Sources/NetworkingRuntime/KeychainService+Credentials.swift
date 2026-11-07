import Foundation
import NetworkingCore

#if canImport(Security)
extension KeychainService {
  func refreshCredential(
    tokenKey: KeychainItemKey,
    refreshKey: KeychainItemKey
  ) throws -> KeychainRefreshCredential? {
    guard let refreshToken = try retrieveString(forKey: refreshKey) else { return nil }
    return KeychainRefreshCredential(
      tokenKey: tokenKey,
      refreshKey: refreshKey,
      accessToken: try retrieveString(forKey: tokenKey),
      refreshToken: refreshToken,
      revision: credentialRevision
    )
  }

  func storeRefreshedToken(
    _ token: BearerTokenValue,
    matching snapshot: KeychainRefreshCredential
  ) throws {
    try Task.checkCancellation()
    guard credentialRevision == snapshot.revision,
      try retrieveString(forKey: snapshot.tokenKey) == snapshot.accessToken,
      try retrieveString(forKey: snapshot.refreshKey) == snapshot.refreshToken
    else {
      throw HTTPError(category: .custom("Authentication", "Credentials changed during refresh"))
    }
    try store(KeychainStringValue(token.rawValue), forKey: snapshot.tokenKey)
  }

  func deleteTokens(tokenKey: KeychainItemKey, refreshKey: KeychainItemKey?) throws {
    try delete(tokenKey)
    if let refreshKey {
      try delete(refreshKey)
    }
  }
}
#endif
