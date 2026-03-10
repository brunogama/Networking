import Foundation
import NetworkingCore

// swiftlint:disable file_length

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

#if canImport(Security)
import Security
#endif

#if canImport(CommonCrypto)
import CommonCrypto
#endif

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

  /// Whether to allow backup certificates (for certificate rotation)
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
    case v1_0
    case v1_1
    case v1_2
    case v1_3
  }
  // swiftlint:enable identifier_name
}

#if canImport(Security)

// swiftlint:disable type_body_length
/// SSL Pinning Validator that handles certificate and public key validation.
public final class SSLPinningValidator: NSObject, URLSessionDelegate {
  private let securityConfiguration: SecurityConfiguration

  public init(securityConfiguration: SecurityConfiguration) {
    self.securityConfiguration = securityConfiguration
    super.init()
  }

  // MARK: - URLSessionDelegate

  public func urlSession(
    _ session: URLSession,
    didReceive challenge: URLAuthenticationChallenge,
    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
  ) {
    guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust
    else {
      completionHandler(.performDefaultHandling, nil)
      return
    }

    guard
      let serverTrust = serverTrust(
        for: challenge,
        completionHandler: completionHandler
      )
    else {
      return
    }

    let host = challenge.protectionSpace.host

    if handlePinning(
      serverTrust: serverTrust,
      host: host,
      completionHandler: completionHandler
    ) {
      return
    }

    if !validateTLSConfiguration(serverTrust: serverTrust) {
      completionHandler(.rejectProtectionSpace, nil)
      return
    }

    // Default handling for domains without pinning
    completionHandler(.performDefaultHandling, nil)
  }

  // MARK: - Private Validation Methods

  private func handlePinning(
    serverTrust: SecTrust,
    host: String,
    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
  ) -> Bool {
    if handleCertificatePinning(
      serverTrust: serverTrust,
      host: host,
      completionHandler: completionHandler
    ) {
      return true
    }

    return handlePublicKeyPinning(
      serverTrust: serverTrust,
      host: host,
      completionHandler: completionHandler
    )
  }

  private func serverTrust(
    for challenge: URLAuthenticationChallenge,
    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
  ) -> SecTrust? {
    guard let serverTrust = challenge.protectionSpace.serverTrust else {
      completionHandler(.rejectProtectionSpace, nil)
      return nil
    }

    return serverTrust
  }

  private func handleCertificatePinning(
    serverTrust: SecTrust,
    host: String,
    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
  ) -> Bool {
    guard let configuration = securityConfiguration.certificatePinning,
      configuration.domains.contains(PinnedDomain(host))
    else {
      return false
    }

    if validateCertificatePinning(serverTrust: serverTrust, configuration: configuration) {
      completeWithCredential(serverTrust: serverTrust, completionHandler: completionHandler)
    } else {
      handleValidationFailure(
        action: configuration.validationFailureAction,
        completionHandler: completionHandler
      )
    }

    return true
  }

  private func handlePublicKeyPinning(
    serverTrust: SecTrust,
    host: String,
    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
  ) -> Bool {
    guard let configuration = securityConfiguration.publicKeyPinning,
      configuration.domains.contains(PinnedDomain(host))
    else {
      return false
    }

    if validatePublicKeyPinning(serverTrust: serverTrust, configuration: configuration) {
      completeWithCredential(serverTrust: serverTrust, completionHandler: completionHandler)
    } else {
      handleValidationFailure(
        action: configuration.validationFailureAction,
        completionHandler: completionHandler
      )
    }

    return true
  }

  private func completeWithCredential(
    serverTrust: SecTrust,
    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
  ) {
    completionHandler(.useCredential, URLCredential(trust: serverTrust))
  }

  private func validateCertificatePinning(
    serverTrust: SecTrust,
    configuration: CertificatePinningConfiguration
  ) -> Bool {
    guard let certificateChain = getServerCertificateChain(serverTrust: serverTrust) else {
      return false
    }

    // Check if any certificate in the chain matches our pinned certificates
    for certificate in certificateChain {
      let certificateHash = CertificateHash(sha256Hash(of: certificate))
      if configuration.pinnedCertificateHashes.contains(certificateHash) {
        return true
      }
    }

    // If backup certificates are allowed, perform additional validation
    if configuration.allowBackupCertificates.rawValue {
      // In a production environment, you might check against backup certificate hashes
      // or perform other fallback validations
    }

    return false
  }

  private func validatePublicKeyPinning(
    serverTrust: SecTrust,
    configuration: PublicKeyPinningConfiguration
  ) -> Bool {
    guard let certificateChain = getServerCertificateChain(serverTrust: serverTrust) else {
      return false
    }

    var foundPinnedKey = false

    // Extract and validate public keys from the certificate chain
    for certificate in certificateChain {
      if let publicKey = SecCertificateCopyKey(certificate) {
        let publicKeyHash = CertificateHash(sha256Hash(of: publicKey))
        if configuration.pinnedPublicKeyHashes.contains(publicKeyHash) {
          foundPinnedKey = true
          break
        }
      }
    }

    return configuration.requirePinnedKey.rawValue ? foundPinnedKey : true
  }

  private func validateTLSConfiguration(serverTrust: SecTrust) -> Bool {
    // Basic TLS validation - in a full implementation, you would check:
    // - TLS version constraints
    // - Custom CA certificates
    // - Certificate chain validation settings

    if !securityConfiguration.tlsConfiguration.validateCertificateChain.rawValue {
      return true
    }

    var error: CFError?
    let isValid = SecTrustEvaluateWithError(serverTrust, &error)

    if let error = error {
      writeToStandardError(
        "TLS validation error: \(String(describing: CFErrorCopyDescription(error)))"
      )
    }

    return isValid
  }

  private func handleValidationFailure(
    action: CertificatePinningConfiguration.ValidationFailureAction,
    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
  ) {
    switch action {
    case .reject:
      completionHandler(.rejectProtectionSpace, nil)

    case .warn:
      writeToStandardError(
        "SSL pinning validation failed, allowing connection due to configuration"
      )
      completionHandler(.performDefaultHandling, nil)

    case .allow:
      completionHandler(.performDefaultHandling, nil)
    }
  }

  private func handleValidationFailure(
    action: PublicKeyPinningConfiguration.ValidationFailureAction,
    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
  ) {
    switch action {
    case .reject:
      completionHandler(.rejectProtectionSpace, nil)

    case .warn:
      writeToStandardError(
        "Public key pinning validation failed, allowing connection due to configuration"
      )
      completionHandler(.performDefaultHandling, nil)

    case .allow:
      completionHandler(.performDefaultHandling, nil)
    }
  }

  // MARK: - Helper Methods

  private func getServerCertificateChain(serverTrust: SecTrust) -> [SecCertificate]? {
    guard let certificateChain = SecTrustCopyCertificateChain(serverTrust) else {
      return nil
    }

    var certificates: [SecCertificate] = []
    let count = CFArrayGetCount(certificateChain)

    for index in 0..<count {
      guard let certificate = CFArrayGetValueAtIndex(certificateChain, index) else {
        continue
      }

      let cert = Unmanaged<SecCertificate>.fromOpaque(certificate).takeUnretainedValue()
      certificates.append(cert)
    }

    return certificates.isEmpty ? nil : certificates
  }

  private func writeToStandardError(_ message: String) {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
  }

  private func sha256Hash(of certificate: SecCertificate) -> String {
    let certificateData = SecCertificateCopyData(certificate)
    let data = CFDataGetBytePtr(certificateData)!
    let length = CFDataGetLength(certificateData)

    var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
    CC_SHA256(data, CC_LONG(length), &digest)

    return digest.map { String(format: "%02x", $0) }.joined()
  }

  private func sha256Hash(of publicKey: SecKey) -> String {
    guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) else {
      return ""
    }

    let data = CFDataGetBytePtr(publicKeyData)!
    let length = CFDataGetLength(publicKeyData)

    var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
    CC_SHA256(data, CC_LONG(length), &digest)

    return digest.map { String(format: "%02x", $0) }.joined()
  }
}
// swiftlint:enable type_body_length

#endif  // canImport(Security)

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
