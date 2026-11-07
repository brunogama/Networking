import NetworkingCore

/// Cache expiration strategies.
public struct ExpirationStrategy: Sendable {

  public let defaultTTL: CacheMaxAge

  public let maxTTL: CacheMaxAge

  public let minTTL: CacheMaxAge

  public let extendOnAccess: CacheExtensionOnAccessFlag

  public let extensionFactor: CacheExtensionFactor

  public init(
    defaultTTL: CacheMaxAge = 300.0,
    maxTTL: CacheMaxAge = 3600.0,
    minTTL: CacheMaxAge = 60.0,
    extendOnAccess: CacheExtensionOnAccessFlag = false,
    extensionFactor: CacheExtensionFactor = 0.5
  ) {
    self.defaultTTL = defaultTTL
    self.maxTTL = maxTTL
    self.minTTL = minTTL
    self.extendOnAccess = extendOnAccess
    self.extensionFactor = CacheExtensionFactor(max(0.0, min(1.0, extensionFactor.rawValue)))
  }
}
