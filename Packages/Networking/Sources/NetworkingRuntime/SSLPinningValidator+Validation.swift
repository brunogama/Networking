import Foundation
import NetworkingCore

#if canImport(Security)
import Security

extension SSLPinningValidator {
  func validateCertificatePinning(
    serverTrust: SecTrust,
    configuration: CertificatePinningConfiguration
  ) -> Bool {
    guard let certificateChain = getServerCertificateChain(serverTrust: serverTrust) else {
      return false
    }

    guard let leafCertificate = certificateChain.first else {
      return false
    }

    let leafHash = CertificateHash(sha256Hash(of: leafCertificate))
    if configuration.pinnedCertificateHashes.contains(leafHash) {
      return true
    }

    guard configuration.allowBackupCertificates.rawValue else {
      return false
    }

    return certificateChain.dropFirst().contains { certificate in
      let certificateHash = CertificateHash(sha256Hash(of: certificate))
      return configuration.pinnedCertificateHashes.contains(certificateHash)
    }
  }

  func validatePublicKeyPinning(
    serverTrust: SecTrust,
    configuration: PublicKeyPinningConfiguration
  ) -> Bool {
    guard let certificateChain = getServerCertificateChain(serverTrust: serverTrust) else {
      return false
    }

    var foundPinnedKey = false

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

  func validateTLSConfiguration(serverTrust: SecTrust, host: String) -> Bool {
    guard configureTrust(serverTrust: serverTrust, host: host) else {
      return false
    }

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

  private func configureTrust(serverTrust: SecTrust, host: String) -> Bool {
    let validateHostname = securityConfiguration.tlsConfiguration.validateHostname.rawValue
    let policyHost = validateHostname ? host as CFString : nil
    SecTrustSetPolicies(serverTrust, SecPolicyCreateSSL(true, policyHost))

    let customCACertificates = securityConfiguration.tlsConfiguration.customCACertificates
    guard !customCACertificates.isEmpty else {
      return true
    }

    let anchors = customCACertificates.compactMap { certificateData in
      SecCertificateCreateWithData(nil, certificateData.rawValue as CFData)
    }

    guard anchors.count == customCACertificates.count else {
      writeToStandardError("TLS validation error: invalid custom CA certificate data")
      return false
    }

    let setAnchorsStatus = SecTrustSetAnchorCertificates(serverTrust, anchors as CFArray)
    guard setAnchorsStatus == errSecSuccess else {
      writeToStandardError(
        "TLS validation error: failed to set custom anchor certificates (\(setAnchorsStatus))"
      )
      return false
    }

    let anchorBehaviorStatus = SecTrustSetAnchorCertificatesOnly(serverTrust, false)
    guard anchorBehaviorStatus == errSecSuccess else {
      writeToStandardError(
        "TLS validation error: failed to configure custom anchor behavior (\(anchorBehaviorStatus))"
      )
      return false
    }

    return true
  }

  func validationFailureDecision(
    for action: CertificatePinningConfiguration.ValidationFailureAction
  ) -> SSLPinningValidationDecision {
    switch action {
    case .reject:
      return .rejectProtectionSpace
    case .warn:
      writeToStandardError(
        "SSL pinning validation failed, allowing connection due to configuration"
      )
      return .performDefaultHandling
    case .allow:
      return .performDefaultHandling
    }
  }

  func validationFailureDecision(
    for action: PublicKeyPinningConfiguration.ValidationFailureAction
  ) -> SSLPinningValidationDecision {
    switch action {
    case .reject:
      return .rejectProtectionSpace
    case .warn:
      writeToStandardError(
        "Public key pinning validation failed, allowing connection due to configuration"
      )
      return .performDefaultHandling
    case .allow:
      return .performDefaultHandling
    }
  }
}

#endif
