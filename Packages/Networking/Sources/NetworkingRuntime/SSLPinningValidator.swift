import Foundation
import NetworkingCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

#if canImport(Security)
import Security

/// SSL Pinning Validator that handles certificate and public key validation.
///
/// URLSession may call this delegate from multiple threads; its configuration is immutable.
public final class SSLPinningValidator: NSObject, URLSessionDelegate, @unchecked Sendable {
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

    let decision = validationDecision(serverTrust: serverTrust, host: host)
    complete(decision, serverTrust: serverTrust, completionHandler: completionHandler)
  }

  func validationDecision(
    serverTrust: SecTrust,
    host: String
  ) -> SSLPinningValidationDecision {
    let certificateDecision = certificatePinningConfiguration(for: host).map { configuration in
      validationDecisionForCertificatePinning(
        serverTrust: serverTrust,
        host: host,
        configuration: configuration
      )
    }

    let publicKeyDecision = publicKeyPinningConfiguration(for: host).map { configuration in
      validationDecisionForPublicKeyPinning(
        serverTrust: serverTrust,
        host: host,
        configuration: configuration
      )
    }

    let decisions = [certificateDecision, publicKeyDecision].compactMap { $0 }
    if decisions.contains(.rejectProtectionSpace) { return .rejectProtectionSpace }
    if decisions.contains(.performDefaultHandling) { return .performDefaultHandling }
    if !decisions.isEmpty { return .useCredential }
    return validateTLSConfiguration(serverTrust: serverTrust, host: host)
      ? .performDefaultHandling : .rejectProtectionSpace
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

  private func validationDecisionForCertificatePinning(
    serverTrust: SecTrust,
    host: String,
    configuration: CertificatePinningConfiguration
  ) -> SSLPinningValidationDecision {
    if securityConfiguration.tlsConfiguration.validateCertificateChain.rawValue,
      !validateTLSConfiguration(serverTrust: serverTrust, host: host)
    {
      return .rejectProtectionSpace
    }

    if validateCertificatePinning(serverTrust: serverTrust, configuration: configuration) {
      return .useCredential
    }

    return validationFailureDecision(for: configuration.validationFailureAction)
  }

  private func validationDecisionForPublicKeyPinning(
    serverTrust: SecTrust,
    host: String,
    configuration: PublicKeyPinningConfiguration
  ) -> SSLPinningValidationDecision {
    if securityConfiguration.tlsConfiguration.validateCertificateChain.rawValue,
      !validateTLSConfiguration(serverTrust: serverTrust, host: host)
    {
      return .rejectProtectionSpace
    }

    if validatePublicKeyPinning(serverTrust: serverTrust, configuration: configuration) {
      return .useCredential
    }

    return validationFailureDecision(for: configuration.validationFailureAction)
  }

  private func certificatePinningConfiguration(
    for host: String
  ) -> CertificatePinningConfiguration? {
    guard let configuration = securityConfiguration.certificatePinning,
      configuration.domains.contains(where: {
        $0.rawValue.caseInsensitiveCompare(host) == .orderedSame
      })
    else {
      return nil
    }

    return configuration
  }

  private func publicKeyPinningConfiguration(
    for host: String
  ) -> PublicKeyPinningConfiguration? {
    guard let configuration = securityConfiguration.publicKeyPinning,
      configuration.domains.contains(where: {
        $0.rawValue.caseInsensitiveCompare(host) == .orderedSame
      })
    else {
      return nil
    }

    return configuration
  }

  private func complete(
    _ decision: SSLPinningValidationDecision,
    serverTrust: SecTrust,
    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
  ) {
    switch decision {
    case .useCredential:
      completionHandler(.useCredential, URLCredential(trust: serverTrust))
    case .performDefaultHandling:
      completionHandler(.performDefaultHandling, nil)
    case .rejectProtectionSpace:
      completionHandler(.rejectProtectionSpace, nil)
    }
  }
}

#endif
