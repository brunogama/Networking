import Foundation
import NetworkingCore
import NetworkingRuntime
import Testing
#if canImport(Security)
import Security
import LocalAuthentication
#endif

struct TokenRefreshRegressionTests {
  @Test(arguments: [BearerTokenValue?.none, BearerTokenValue("replacement")])
  func memoryRefreshCannotOverwriteChanges(replacement: BearerTokenValue?) async throws {
    let exchange = SuspendedTokenExchange()
    let provider = MemoryTokenProvider(initialToken: "old") { await exchange.refresh() }

    await withTaskGroup(of: Void.self) { group in
      group.addTask {
        await #expect(throws: HTTPError.self) { try await provider.refreshToken() }
      }
      await exchange.waitUntilStarted()
      await provider.setToken(replacement)
      await exchange.finish()
    }

    #expect(try await provider.getCurrentToken() == replacement)
  }

  #if canImport(Security)
  @Test(.enabled(if: keychainAvailable, "An unlocked default keychain is required"))
  func keychainRefreshCannotUndoLogout() async throws {
    let service = KeychainService(service: KeychainServiceName(UUID().uuidString))
    let exchange = SuspendedTokenExchange()
    let provider = KeychainTokenProvider(keychainService: service) { _ in
      await exchange.refresh()
    }
    try await provider.storeToken("old")
    try await provider.storeRefreshToken("refresh")

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        await #expect(throws: HTTPError.self) { try await provider.refreshToken() }
      }
      await exchange.waitUntilStarted()
      try await exchange.finishAfterMutation {
        try await provider.clearTokens()
      }
      try await group.waitForAll()
    }

    #expect(try await provider.getCurrentToken() == nil)
    #expect(try await service.retrieveString(forKey: "refresh_token") == nil)
    try await service.deleteAll()
  }

  @Test(.enabled(if: keychainAvailable, "An unlocked default keychain is required"))
  func keychainRefreshCannotReplaceNewLogin() async throws {
    let service = KeychainService(service: KeychainServiceName(UUID().uuidString))
    let exchange = SuspendedTokenExchange()
    let provider = KeychainTokenProvider(keychainService: service) { _ in
      await exchange.refresh()
    }
    try await provider.storeToken("old")
    try await provider.storeRefreshToken("refresh")

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        await #expect(throws: HTTPError.self) { try await provider.refreshToken() }
      }
      await exchange.waitUntilStarted()
      try await exchange.finishAfterMutation {
        try await provider.storeToken("replacement")
        try await provider.storeRefreshToken("replacement-refresh")
      }
      try await group.waitForAll()
    }

    #expect(try await provider.getCurrentToken() == "replacement")
    #expect(try await service.retrieveString(forKey: "refresh_token") == "replacement-refresh")
    try await service.deleteAll()
  }

  private static var keychainAvailable: Bool {
    !keychainIsUnavailable()
  }

  #endif
}

#if canImport(Security)
func keychainIsUnavailable() -> Bool {
  let context = LAContext()
  context.interactionNotAllowed = true
  var query: [CFString: Any] = [
    kSecClass: kSecClassGenericPassword,
    kSecAttrService: "NetworkingTests.Probe.\(UUID().uuidString)",
    kSecAttrAccount: "availability",
    kSecValueData: Data(),
    kSecUseAuthenticationContext: context,
  ]
  let status = SecItemAdd(query as CFDictionary, nil)
  if status == errSecSuccess {
    query[kSecValueData] = nil
    let deletionStatus = SecItemDelete(query as CFDictionary)
    #expect(deletionStatus == errSecSuccess)
  }
  return [errSecNoDefaultKeychain, errSecNoSuchKeychain, errSecInteractionNotAllowed].contains(
    status
  )
}
#endif
