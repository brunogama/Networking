import Foundation
import NetworkingCore

// MARK: - Platform-specific Keychain Implementation

#if canImport(Security)

/// Secure storage service using iOS/macOS Keychain for sensitive data like authentication tokens.
///
/// This is implemented as an actor to ensure thread-safe access to keychain operations.
/// All keychain operations are serialized through actor isolation.
public actor KeychainService {

  // MARK: - Properties

  let configuration: Configuration
  var credentialRevision = UUID()

  // MARK: - Initialization

  public init(configuration: Configuration) {
    self.configuration = configuration
  }

  public init(service: KeychainServiceName) {
    self.configuration = Configuration(service: service)
  }
}

// MARK: - Convenience Extensions

extension KeychainService {

  public static let `default` = KeychainService(
    configuration: Configuration(service: "Networking")
  )

  public static func app(_ bundleIdentifier: KeychainServiceName) -> KeychainService {
    KeychainService(
      configuration: Configuration(
        service: bundleIdentifier,
        accessibility: .whenUnlockedThisDeviceOnly
      )
    )
  }

  public static func synced(
    service: KeychainServiceName,
    accessGroup: KeychainAccessGroup? = nil
  ) -> KeychainService {
    KeychainService(
      configuration: Configuration(
        service: service,
        accessGroup: accessGroup,
        accessibility: .whenUnlocked,
        synchronizable: true
      )
    )
  }
}

#endif  // canImport(Security)
