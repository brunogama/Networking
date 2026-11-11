import NetworkingCore

/// Configuration for public key pinning (recommended over certificate pinning).
public struct PublicKeyPinningConfiguration: Sendable {

  public let pinnedPublicKeyHashes: Set<CertificateHash>

  public let domains: Set<PinnedDomain>

  public let requirePinnedKey: PinnedKeyRequirement

  public let validationFailureAction: ValidationFailureAction

  public init(
    pinnedPublicKeyHashes: Set<CertificateHash>,
    domains: Set<PinnedDomain>,
    requirePinnedKey: PinnedKeyRequirement = true,
    validationFailureAction: ValidationFailureAction = .reject
  ) {
    self.pinnedPublicKeyHashes = pinnedPublicKeyHashes
    self.domains = domains
    self.requirePinnedKey = requirePinnedKey
    self.validationFailureAction = validationFailureAction
  }
}
