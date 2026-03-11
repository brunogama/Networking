import Foundation
import NetworkingCore

#if canImport(Security)
import Security
#endif

// MARK: - Platform-specific Keychain Implementation

#if canImport(Security)

/// Secure storage service using iOS/macOS Keychain for sensitive data like authentication tokens.
///
/// This is implemented as an actor to ensure thread-safe access to keychain operations.
/// All keychain operations are serialized through actor isolation.
public actor KeychainService {
  // MARK: - Configuration

  public struct Configuration: Sendable {
    /// Service identifier for keychain items
    public let service: KeychainServiceName

    /// Access group for keychain sharing between apps
    public let accessGroup: KeychainAccessGroup?

    /// Keychain accessibility level
    public let accessibility: KeychainAccessibility

    /// Whether to synchronize keychain items across devices via iCloud
    public let synchronizable: KeychainSynchronizableFlag

    public init(
      service: KeychainServiceName,
      accessGroup: KeychainAccessGroup? = nil,
      accessibility: KeychainAccessibility = .whenUnlockedThisDeviceOnly,
      synchronizable: KeychainSynchronizableFlag = false
    ) {
      self.service = service
      self.accessGroup = accessGroup
      self.accessibility = accessibility
      self.synchronizable = synchronizable
    }
  }

  public enum KeychainAccessibility: Sendable {
    case whenUnlocked
    case whenUnlockedThisDeviceOnly
    case afterFirstUnlock
    case afterFirstUnlockThisDeviceOnly
    case whenPasscodeSetThisDeviceOnly

    var rawValue: CFString {
      switch self {
      case .whenUnlocked:
        return kSecAttrAccessibleWhenUnlocked

      case .whenUnlockedThisDeviceOnly:
        return kSecAttrAccessibleWhenUnlockedThisDeviceOnly

      case .afterFirstUnlock:
        return kSecAttrAccessibleAfterFirstUnlock

      case .afterFirstUnlockThisDeviceOnly:
        return kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

      case .whenPasscodeSetThisDeviceOnly:
        return kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
      }
    }
  }

  // MARK: - Properties

  let configuration: Configuration

  // MARK: - Initialization

  public init(configuration: Configuration) {
    self.configuration = configuration
  }

  /// Initializer with service name (creates default configuration)
  public init(service: KeychainServiceName) {
    self.configuration = Configuration(service: service)
  }
}

// MARK: - Convenience Extensions

extension KeychainService {
  /// Default keychain service for the Networking framework
  public static let `default` = KeychainService(
    configuration: Configuration(service: "Networking")
  )

  /// Creates a keychain service for a specific app
  public static func app(_ bundleIdentifier: KeychainServiceName) -> KeychainService {
    KeychainService(
      configuration: Configuration(
        service: bundleIdentifier,
        accessibility: .whenUnlockedThisDeviceOnly
      )
    )
  }

  /// Creates a keychain service with iCloud sync enabled
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
