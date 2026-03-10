import Foundation
import NetworkingCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

#if canImport(Security)
import Security

/// SSL Pinning Validator that handles certificate and public key validation.
public final class SSLPinningValidator: NSObject, URLSessionDelegate {
  let securityConfiguration: SecurityConfiguration

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

    completionHandler(.performDefaultHandling, nil)
  }

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
}

#endif
