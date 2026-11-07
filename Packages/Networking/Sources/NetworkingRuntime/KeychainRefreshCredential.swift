import Foundation
import NetworkingCore

#if canImport(Security)
struct KeychainRefreshCredential: Sendable {
  let tokenKey: KeychainItemKey
  let refreshKey: KeychainItemKey
  let accessToken: KeychainStringValue?
  let refreshToken: KeychainStringValue
  let revision: UUID
}
#endif
