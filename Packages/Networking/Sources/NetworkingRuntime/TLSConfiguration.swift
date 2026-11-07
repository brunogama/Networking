import NetworkingCore

/// TLS configuration options.
public struct TLSConfiguration: Sendable {
  /// Minimum TLS version to allow.
  public let minimumTLSVersion: TLSVersion

  /// Maximum TLS version to allow.
  public let maximumTLSVersion: TLSVersion

  /// Whether to validate the certificate chain.
  public let validateCertificateChain: TLSChainValidationFlag

  /// Whether to validate the hostname.
  public let validateHostname: TLSHostnameValidationFlag

  /// Custom certificate authority certificates to trust.
  public let customCACertificates: [CACertificateData]

  /// Configures protocol bounds, certificate trust, and hostname validation.
  public init(
    minimumTLSVersion: TLSVersion = .tls12,
    maximumTLSVersion: TLSVersion = .tls13,
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

  /// Uses TLS 1.2 through 1.3 with certificate and hostname validation.
  public static let `default` = Self()
}
