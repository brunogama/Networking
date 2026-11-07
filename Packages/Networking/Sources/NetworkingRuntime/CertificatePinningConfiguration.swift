import NetworkingCore

/// Configuration for certificate pinning.
public struct CertificatePinningConfiguration: Sendable {
  /// Pinned certificates stored as SHA-256 hashes.
  public let pinnedCertificateHashes: Set<CertificateHash>

  /// Domains to apply certificate pinning to.
  public let domains: Set<PinnedDomain>

  /// Whether non-leaf certificates in the chain may satisfy the configured pins.
  public let allowBackupCertificates: BackupCertificateAllowance

  /// Action to take when certificate validation fails.
  public let validationFailureAction: ValidationFailureAction

  /// Configures accepted certificate hashes and the hosts where they apply.
  public init(
    pinnedCertificateHashes: Set<CertificateHash>,
    domains: Set<PinnedDomain>,
    allowBackupCertificates: BackupCertificateAllowance = true,
    validationFailureAction: ValidationFailureAction = .reject
  ) {
    self.pinnedCertificateHashes = pinnedCertificateHashes
    self.domains = domains
    self.allowBackupCertificates = allowBackupCertificates
    self.validationFailureAction = validationFailureAction
  }
}
