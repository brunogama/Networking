import NetworkingCore

#if canImport(Security)
extension KeychainService {
  // MARK: - Configuration

  /// Names and access policy for this service's keychain items.
  public struct Configuration: Sendable {
    /// Service identifier for keychain items.
    public let service: KeychainServiceName

    /// Access group for keychain sharing between apps.
    public let accessGroup: KeychainAccessGroup?

    /// Keychain accessibility level.
    public let accessibility: KeychainAccessibility

    /// Whether to synchronize keychain items across devices via iCloud.
    public let synchronizable: KeychainSynchronizableFlag

    /// Creates the service namespace and storage access policy.
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
}
#endif
