import NetworkingCore

/// TLS configuration options.
public struct TLSConfiguration: Sendable {

  public let minimumTLSVersion: TLSVersion

  public let maximumTLSVersion: TLSVersion

  public let validateCertificateChain: TLSChainValidationFlag

  public let validateHostname: TLSHostnameValidationFlag

  public let customCACertificates: [CACertificateData]

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

  public static let `default` = Self()
}
