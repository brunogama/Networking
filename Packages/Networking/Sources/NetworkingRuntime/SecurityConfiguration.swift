import NetworkingCore

/// Configuration for security-related networking features.
public struct SecurityConfiguration: Sendable {

  public let certificatePinning: CertificatePinningConfiguration?

  public let tlsConfiguration: TLSConfiguration

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

// MARK: - Convenience Extensions

extension SecurityConfiguration {

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
