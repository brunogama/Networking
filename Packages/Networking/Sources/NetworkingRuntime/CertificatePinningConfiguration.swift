import NetworkingCore

/// Configuration for certificate pinning.
public struct CertificatePinningConfiguration: Sendable {

  public let pinnedCertificateHashes: Set<CertificateHash>

  public let domains: Set<PinnedDomain>

  public let allowBackupCertificates: BackupCertificateAllowance

  public let validationFailureAction: ValidationFailureAction

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
