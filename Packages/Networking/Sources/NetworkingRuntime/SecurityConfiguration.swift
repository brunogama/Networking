import Foundation
import NetworkingCore

/// Configuration for security-related networking features.
public struct SecurityConfiguration: Sendable {
  /// Certificate pinning configuration
  public let certificatePinning: CertificatePinningConfiguration?

  /// TLS configuration options
  public let tlsConfiguration: TLSConfiguration

  /// Public key pinning configuration (more flexible than certificate pinning)
  public let publicKeyPinning: PublicKeyPinningConfiguration?

  public init(
    certificatePinning: CertificatePinningConfiguration? = nil,
    tlsConfiguration: TLSConfiguration = .default,
    publicKeyPinning: PublicKeyPinningConfiguration? = nil
  ) {
    self.certificatePinning = certificatePinning
    self.tlsConfiguration = tlsConfiguration
    self.publicKeyPinning = publicKeyPinning
  }

  public static let `default` = Self()
}

/// Configuration for certificate pinning.
public struct CertificatePinningConfiguration: Sendable {
  /// Pinned certificates stored as SHA-256 hashes
  public let pinnedCertificateHashes: Set<CertificateHash>

  /// Domains to apply certificate pinning to
  public let domains: Set<PinnedDomain>

  /// Whether non-leaf certificates in the chain may satisfy the configured pins.
  public let allowBackupCertificates: BackupCertificateAllowance

  /// Action to take when certificate validation fails
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

  public enum ValidationFailureAction: Sendable {
    case reject
    case warn
    case allow
  }
}

/// Configuration for public key pinning (recommended over certificate pinning).
public struct PublicKeyPinningConfiguration: Sendable {
  /// Pinned public key hashes (SPKI SHA-256 hashes)
  public let pinnedPublicKeyHashes: Set<CertificateHash>

  /// Domains to apply public key pinning to
  public let domains: Set<PinnedDomain>

  /// Whether to require at least one pinned key in the certificate chain
  public let requirePinnedKey: PinnedKeyRequirement

  /// Action to take when validation fails
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

  public enum ValidationFailureAction: Sendable {
    case reject
    case warn
    case allow
  }
}

/// TLS configuration options.
public struct TLSConfiguration: Sendable {
  /// Minimum TLS version to allow
  public let minimumTLSVersion: TLSVersion

  /// Maximum TLS version to allow
  public let maximumTLSVersion: TLSVersion

  /// Whether to validate the certificate chain
  public let validateCertificateChain: TLSChainValidationFlag

  /// Whether to validate the hostname
  public let validateHostname: TLSHostnameValidationFlag

  /// Custom certificate authority certificates to trust
  public let customCACertificates: [CACertificateData]

  public init(
    minimumTLSVersion: TLSVersion = .v1_2,
    maximumTLSVersion: TLSVersion = .v1_3,
    validateCertificateChain: TLSChainValidationFlag = true,
    validateHostname: TLSHostnameValidationFlag = true,
    customCACertificates: [CACertificateData] = []
  ) {
    self.minimumTLSVersion = minimumTLSVersion
    self.maximumTLSVersion = maximumTLSVersion
    self.validateCertificateChain = validateCertificateChain
    self.validateHostname = validateHostname
    self.customCACertificates = customCACertificates
  }

  public static let `default` = Self()

  // swiftlint:disable identifier_name
  public enum TLSVersion: Sendable {
    case v1_2
    case v1_3
  }
  // swiftlint:enable identifier_name
}

// MARK: - Convenience Extensions

extension SecurityConfiguration {
  /// Creates a security configuration with certificate pinning for specific domains.
  /// - Parameters:
  ///   - certificateHashes: SHA-256 hashes of pinned certificates
  ///   - domains: Domains to apply certificate pinning to
  /// - Returns: SecurityConfiguration with certificate pinning enabled
  public static func withCertificatePinning(
    certificateHashes: Set<CertificateHash>,
    domains: Set<PinnedDomain>
  ) -> SecurityConfiguration {
    let pinningConfig = CertificatePinningConfiguration(
      pinnedCertificateHashes: certificateHashes,
      domains: domains
    )
    return SecurityConfiguration(certificatePinning: pinningConfig)
  }

  /// Creates a security configuration with public key pinning for specific domains.
  /// - Parameters:
  ///   - publicKeyHashes: SHA-256 hashes of pinned public keys
  ///   - domains: Domains to apply public key pinning to
  /// - Returns: SecurityConfiguration with public key pinning enabled
  public static func withPublicKeyPinning(
    publicKeyHashes: Set<CertificateHash>,
    domains: Set<PinnedDomain>
  ) -> SecurityConfiguration {
    let pinningConfig = PublicKeyPinningConfiguration(
      pinnedPublicKeyHashes: publicKeyHashes,
      domains: domains
    )
    return SecurityConfiguration(publicKeyPinning: pinningConfig)
  }

  /// Creates a security configuration with strict TLS requirements.
  /// - Returns: SecurityConfiguration with TLS 1.3 minimum and strict validation
  public static var strict: SecurityConfiguration {
    let tlsConfig = TLSConfiguration(
      minimumTLSVersion: .v1_3,
      maximumTLSVersion: .v1_3,
      validateCertificateChain: true,
      validateHostname: true
    )
    return SecurityConfiguration(tlsConfiguration: tlsConfig)
  }
}
