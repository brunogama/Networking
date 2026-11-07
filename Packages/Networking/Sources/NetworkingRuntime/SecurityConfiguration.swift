import NetworkingCore

/// Configuration for security-related networking features.
public struct SecurityConfiguration: Sendable {
  /// Certificate pinning configuration.
  public let certificatePinning: CertificatePinningConfiguration?

  /// TLS configuration options.
  public let tlsConfiguration: TLSConfiguration

  /// Public key pinning configuration (more flexible than certificate pinning).
  public let publicKeyPinning: PublicKeyPinningConfiguration?

  /// Combines TLS trust requirements with optional certificate and public-key pins.
  public init(
    certificatePinning: CertificatePinningConfiguration? = nil,
    tlsConfiguration: TLSConfiguration = .default,
    publicKeyPinning: PublicKeyPinningConfiguration? = nil
  ) {
    self.certificatePinning = certificatePinning
    self.tlsConfiguration = tlsConfiguration
    self.publicKeyPinning = publicKeyPinning
  }

  /// Uses platform trust with no additional pins.
  public static let `default` = Self()
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
      minimumTLSVersion: .tls13,
      maximumTLSVersion: .tls13,
      validateCertificateChain: true,
      validateHostname: true
    )
    return SecurityConfiguration(tlsConfiguration: tlsConfig)
  }
}
