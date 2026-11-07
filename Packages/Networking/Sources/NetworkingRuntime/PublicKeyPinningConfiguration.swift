import NetworkingCore

/// Configuration for public key pinning (recommended over certificate pinning).
public struct PublicKeyPinningConfiguration: Sendable {
  /// Pinned public key hashes (SPKI SHA-256 hashes).
  public let pinnedPublicKeyHashes: Set<CertificateHash>

  /// Domains to apply public key pinning to.
  public let domains: Set<PinnedDomain>

  /// Whether to require at least one pinned key in the certificate chain.
  public let requirePinnedKey: PinnedKeyRequirement

  /// Action to take when validation fails.
  public let validationFailureAction: ValidationFailureAction

  /// Configures accepted SPKI hashes and the hosts where they apply.
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
