import NetworkingCore

#if canImport(Security)
extension KeychainService {
  // MARK: - Configuration

  /// Names and access policy for this service's keychain items.
  public struct Configuration: Sendable {

    public let service: KeychainServiceName

    public let accessGroup: KeychainAccessGroup?

    public let accessibility: KeychainAccessibility

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
}
#endif
