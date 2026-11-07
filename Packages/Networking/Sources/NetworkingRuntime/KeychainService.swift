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

  /// Creates an actor that serializes operations for the supplied service configuration.
  public init(configuration: Configuration) {
    self.configuration = configuration
  }

  /// Creates a service with the default storage access policy.
  public init(service: KeychainServiceName) {
    self.configuration = Configuration(service: service)
  }
}

// MARK: - Convenience Extensions

extension KeychainService {
  /// Default keychain service for the Networking framework.
  public static let `default` = KeychainService(
    configuration: Configuration(service: "Networking")
  )

  /// Creates a keychain service for a specific app.
  public static func app(_ bundleIdentifier: KeychainServiceName) -> KeychainService {
    KeychainService(
      configuration: Configuration(
        service: bundleIdentifier,
        accessibility: .whenUnlockedThisDeviceOnly
      )
    )
  }

  /// Creates a keychain service with iCloud sync enabled.
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
