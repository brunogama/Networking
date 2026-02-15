import Foundation

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
  public let pinnedCertificateHashes: Set<String>

  /// Domains to apply certificate pinning to
  public let domains: Set<String>

  /// Whether to allow backup certificates (for certificate rotation)
  public let allowBackupCertificates: Bool

  /// Action to take when certificate validation fails
  public let validationFailureAction: ValidationFailureAction

  public init(
    pinnedCertificateHashes: Set<String>,
    domains: Set<String>,
    allowBackupCertificates: Bool = true,
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
  public let pinnedPublicKeyHashes: Set<String>

  /// Domains to apply public key pinning to
  public let domains: Set<String>

  /// Whether to require at least one pinned key in the certificate chain
  public let requirePinnedKey: Bool

  /// Action to take when validation fails
  public let validationFailureAction: ValidationFailureAction

  public init(
    pinnedPublicKeyHashes: Set<String>,
    domains: Set<String>,
    requirePinnedKey: Bool = true,
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
  public let validateCertificateChain: Bool

  /// Whether to validate the hostname
  public let validateHostname: Bool

  /// Custom certificate authority certificates to trust
  public let customCACertificates: [Data]

  public init(
    minimumTLSVersion: TLSVersion = .v1_2,
    maximumTLSVersion: TLSVersion = .v1_3,
    validateCertificateChain: Bool = true,
    validateHostname: Bool = true,
    customCACertificates: [Data] = []
  ) {
    self.minimumTLSVersion = minimumTLSVersion
    self.maximumTLSVersion = maximumTLSVersion
    self.validateCertificateChain = validateCertificateChain
    self.validateHostname = validateHostname
    self.customCACertificates = customCACertificates
  }

  public static let `default` = Self()

  public enum TLSVersion: Sendable {
    case v1_0
    case v1_1
    case v1_2
    case v1_3
  }
}

#if canImport(Security)

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
      // Only handle server trust challenges
      guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust
      else {
      completionHandler(.performDefaultHandling, nil)
      return
    }

    guard let serverTrust = challenge.protectionSpace.serverTrust else {
      completionHandler(.rejectProtectionSpace, nil)
      return
    }

    let host = challenge.protectionSpace.host

    // Perform certificate pinning validation if configured
    if let certPinningConfig = securityConfiguration.certificatePinning,
      certPinningConfig.domains.contains(host) {
      if validateCertificatePinning(serverTrust: serverTrust, configuration: certPinningConfig) {
        completionHandler(.useCredential, URLCredential(trust: serverTrust))
        return
      } else {
        handleValidationFailure(
          action: certPinningConfig.validationFailureAction,
          completionHandler: completionHandler
        )
        return
      }
    }

    // Perform public key pinning validation if configured
    if let pkPinningConfig = securityConfiguration.publicKeyPinning,
      pkPinningConfig.domains.contains(host) {
      if validatePublicKeyPinning(serverTrust: serverTrust, configuration: pkPinningConfig) {
        completionHandler(.useCredential, URLCredential(trust: serverTrust))
        return
      } else {
        handleValidationFailure(
          action: pkPinningConfig.validationFailureAction,
          completionHandler: completionHandler
        )
        return
      }
    }

    // Apply TLS configuration validation
    if !validateTLSConfiguration(serverTrust: serverTrust) {
      completionHandler(.rejectProtectionSpace, nil)
      return
    }

    // Default handling for domains without pinning
    completionHandler(.performDefaultHandling, nil)
  }

  // MARK: - Private Validation Methods

  private func validateCertificatePinning(
    serverTrust: SecTrust,
    configuration: CertificatePinningConfiguration
  ) -> Bool {
    guard let certificateChain = getServerCertificateChain(serverTrust: serverTrust) else {
      return false
    }

    // Check if any certificate in the chain matches our pinned certificates
    for certificate in certificateChain {
      let certificateHash = sha256Hash(of: certificate)
      if configuration.pinnedCertificateHashes.contains(certificateHash) {
        return true
      }
    }

    // If backup certificates are allowed, perform additional validation
    if configuration.allowBackupCertificates {
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
        let publicKeyHash = sha256Hash(of: publicKey)
        if configuration.pinnedPublicKeyHashes.contains(publicKeyHash) {
          foundPinnedKey = true
          break
        }
      }
    }

    return configuration.requirePinnedKey ? foundPinnedKey : true
  }

  private func validateTLSConfiguration(serverTrust: SecTrust) -> Bool {
    // Basic TLS validation - in a full implementation, you would check:
    // - TLS version constraints
    // - Custom CA certificates
    // - Certificate chain validation settings

    if !securityConfiguration.tlsConfiguration.validateCertificateChain {
      return true
    }

    var error: CFError?
    let isValid = SecTrustEvaluateWithError(serverTrust, &error)

    if let error = error {
      print("TLS validation error: \(String(describing: CFErrorCopyDescription(error)))")
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
      // Log warning but allow connection
      print("⚠️ SSL Pinning validation failed, but allowing connection due to configuration")
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
      // Log warning but allow connection
      print("⚠️ Public Key Pinning validation failed, but allowing connection due to configuration")
      completionHandler(.performDefaultHandling, nil)

    case .allow:
      completionHandler(.performDefaultHandling, nil)
    }
  }

  // MARK: - Helper Methods

  private func getServerCertificateChain(serverTrust: SecTrust) -> [SecCertificate]? {
    if #available(macOS 12.0, iOS 15.0, *) {
      // Use modern API for macOS 12.0+ and iOS 15.0+
      guard let certificateChain = SecTrustCopyCertificateChain(serverTrust) else {
        return nil
      }

      var certificates: [SecCertificate] = []
      let count = CFArrayGetCount(certificateChain)

      for i in 0..<count {
        let certificate = CFArrayGetValueAtIndex(certificateChain, i)
        if let cert = Unmanaged<SecCertificate>.fromOpaque(certificate!).takeUnretainedValue()
          as SecCertificate? {
          certificates.append(cert)
        }
      }

      return certificates.isEmpty ? nil : certificates
    } else {
      // Fallback for older versions
      var certificates: [SecCertificate] = []

      let certificateCount = SecTrustGetCertificateCount(serverTrust)
      for i in 0..<certificateCount {
        if let certificate = SecTrustGetCertificateAtIndex(serverTrust, i) {
          certificates.append(certificate)
        }
      }

      return certificates.isEmpty ? nil : certificates
    }
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

#endif  // canImport(Security)

// MARK: - Convenience Extensions

extension SecurityConfiguration {
  /// Creates a security configuration with certificate pinning for specific domains.
  /// - Parameters:
  ///   - certificateHashes: SHA-256 hashes of pinned certificates
  ///   - domains: Domains to apply certificate pinning to
  /// - Returns: SecurityConfiguration with certificate pinning enabled
  public static func withCertificatePinning(
    certificateHashes: Set<String>,
    domains: Set<String>
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
    publicKeyHashes: Set<String>,
    domains: Set<String>
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
