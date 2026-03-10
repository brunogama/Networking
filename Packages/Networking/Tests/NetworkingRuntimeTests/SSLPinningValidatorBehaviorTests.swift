import Foundation
import XCTest

#if canImport(Network)
import Network
#endif

#if canImport(Security)
import Security

@testable import NetworkingRuntime
import NetworkingCore

final class SSLPinningValidatorBehaviorTests: XCTestCase {
  private let validHost = SSLPinningTestFixtures.validHost
  private let invalidHost = SSLPinningTestFixtures.invalidHost

  func testCertificatePinningRejectsPinnedCertificateWhenTrustIsInvalid() throws {
    let leafCertificate = try SSLPinningTestFixtures.leafCertificate()
    let validator = try SSLPinningTestFixtures.certificatePinningValidator(
      pinnedCertificateHashes: [SSLPinningTestFixtures.certificateHash(for: leafCertificate)],
      domains: [PinnedDomain(validHost)],
      includeRootAnchor: false
    )

    let decision = validator.validationDecision(
      serverTrust: try makeTrust(),
      host: validHost
    )

    XCTAssertEqual(decision, .rejectProtectionSpace)
  }

  func testCertificatePinningUsesCredentialWhenTrustAndPinMatch() throws {
    let leafCertificate = try SSLPinningTestFixtures.leafCertificate()
    let validator = try SSLPinningTestFixtures.certificatePinningValidator(
      pinnedCertificateHashes: [SSLPinningTestFixtures.certificateHash(for: leafCertificate)],
      domains: [PinnedDomain(validHost)]
    )

    let decision = validator.validationDecision(
      serverTrust: try makeTrust(),
      host: validHost
    )

    XCTAssertEqual(decision, .useCredential)
  }

  func testPublicKeyPinningUsesDocumentedSPKIHashes() throws {
    let validator = try SSLPinningTestFixtures.publicKeyPinningValidator(
      pinnedPublicKeyHashes: [CertificateHash(SSLPinningTestFixtures.leafSPKIHash)],
      domains: [PinnedDomain(validHost)]
    )

    let decision = validator.validationDecision(
      serverTrust: try makeTrust(),
      host: validHost
    )

    XCTAssertEqual(decision, .useCredential)
  }

  func testPublicKeyPinningRejectsRawKeyHashes() throws {
    let leafCertificate = try SSLPinningTestFixtures.leafCertificate()
    let validator = try SSLPinningTestFixtures.publicKeyPinningValidator(
      pinnedPublicKeyHashes: [try SSLPinningTestFixtures.rawPublicKeyHash(for: leafCertificate)],
      domains: [PinnedDomain(validHost)]
    )

    let decision = validator.validationDecision(
      serverTrust: try makeTrust(),
      host: validHost
    )

    XCTAssertEqual(decision, .rejectProtectionSpace)
  }

  func testCustomCACertificatesEnableTrustValidation() throws {
    let validator = try SSLPinningTestFixtures.anchoredTLSValidator()

    let decision = validator.validationDecision(
      serverTrust: try makeTrust(),
      host: validHost
    )

    XCTAssertEqual(decision, .performDefaultHandling)
  }

  func testValidateHostnameRejectsMismatchedHost() throws {
    let validator = try SSLPinningTestFixtures.anchoredTLSValidator()

    let decision = validator.validationDecision(
      serverTrust: try makeTrust(),
      host: invalidHost
    )

    XCTAssertEqual(decision, .rejectProtectionSpace)
  }

  func testValidateHostnameCanBeDisabled() throws {
    let validator = try SSLPinningTestFixtures.anchoredTLSValidator(validateHostname: false)

    let decision = validator.validationDecision(
      serverTrust: try makeTrust(),
      host: invalidHost
    )

    XCTAssertEqual(decision, .performDefaultHandling)
  }

  func testAllowBackupCertificatesControlsNonLeafMatches() throws {
    let rootCertificate = try SSLPinningTestFixtures.rootCertificate()
    let rootHash = SSLPinningTestFixtures.certificateHash(for: rootCertificate)

    let strictValidator = try SSLPinningTestFixtures.certificatePinningValidator(
      pinnedCertificateHashes: [rootHash],
      domains: [PinnedDomain(validHost)]
    )
    XCTAssertEqual(
      strictValidator.validationDecision(
        serverTrust: try makeTrust(),
        host: validHost
      ),
      .rejectProtectionSpace
    )

    let backupAwareValidator = try SSLPinningTestFixtures.certificatePinningValidator(
      pinnedCertificateHashes: [rootHash],
      domains: [PinnedDomain(validHost)],
      allowBackupCertificates: true
    )
    XCTAssertEqual(
      backupAwareValidator.validationDecision(
        serverTrust: try makeTrust(),
        host: validHost
      ),
      .useCredential
    )
  }

  func testTLSVersionsApplyToSessionConfiguration() throws {
    #if canImport(Network)
    let sessionConfiguration = SessionConfiguration()
    let securityConfiguration = SecurityConfiguration(
      tlsConfiguration: TLSConfiguration(
        minimumTLSVersion: .v1_2,
        maximumTLSVersion: .v1_3
      )
    )

    let urlSessionConfiguration = sessionConfiguration.configuredURLSessionConfiguration(
      securityConfiguration: securityConfiguration
    )

    XCTAssertEqual(urlSessionConfiguration.tlsMinimumSupportedProtocolVersion, .TLSv12)
    XCTAssertEqual(urlSessionConfiguration.tlsMaximumSupportedProtocolVersion, .TLSv13)
    #else
    throw XCTSkip("Network framework unavailable")
    #endif
  }

  private func makeTrust() throws -> SecTrust {
    try SSLPinningTestFixtures.makeTrust()
  }
}

#endif
