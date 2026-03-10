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

    for certificate in certificateChain {
      let certificateHash = CertificateHash(sha256Hash(of: certificate))
      if configuration.pinnedCertificateHashes.contains(certificateHash) {
        return true
      }
    }

    if configuration.allowBackupCertificates.rawValue {
      // In a production environment, you might check backup pins here.
    }

    return false
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

  func validateTLSConfiguration(serverTrust: SecTrust) -> Bool {
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

  func handleValidationFailure(
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

  func handleValidationFailure(
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
}

#endif
