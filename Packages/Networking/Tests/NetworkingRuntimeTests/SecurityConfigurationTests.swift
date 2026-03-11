// swiftlint:disable file_length
import Foundation
import XCTest

@testable import NetworkingRuntime
import NetworkingCore
import NetworkingDSL
import NetworkingRuntimeDSL
import NetworkingTesting

// Comprehensive tests for SecurityConfiguration TLS and certificate pinning.
// swiftlint:disable:next type_body_length
final class SecurityConfigurationTests: XCTestCase {
  // MARK: - SecurityConfiguration Tests

  func testDefaultSecurityConfiguration() {
    let config = SecurityConfiguration.default

    XCTAssertNil(config.certificatePinning)
    XCTAssertNil(config.publicKeyPinning)
    XCTAssertNotNil(config.tlsConfiguration)
  }

  func testSecurityConfigurationInitialization() {
    let config = SecurityConfiguration(
      certificatePinning: nil,
      tlsConfiguration: .default,
      publicKeyPinning: nil
    )

    XCTAssertNil(config.certificatePinning)
    XCTAssertNil(config.publicKeyPinning)
  }

  func testSecurityConfigurationWithCertificatePinning() {
    let certConfig = CertificatePinningConfiguration(
      pinnedCertificateHashes: ["hash1", "hash2"],
      domains: ["example.com"]
    )

    let config = SecurityConfiguration(certificatePinning: certConfig)

    XCTAssertNotNil(config.certificatePinning)
    XCTAssertEqual(config.certificatePinning?.pinnedCertificateHashes.count, 2)
  }

  func testSecurityConfigurationWithPublicKeyPinning() {
    let pkConfig = PublicKeyPinningConfiguration(
      pinnedPublicKeyHashes: ["pkHash1"],
      domains: ["api.example.com"]
    )

    let config = SecurityConfiguration(publicKeyPinning: pkConfig)

    XCTAssertNotNil(config.publicKeyPinning)
    XCTAssertEqual(config.publicKeyPinning?.domains, Set([PinnedDomain("api.example.com")]))
  }

  // MARK: - CertificatePinningConfiguration Tests

  func testCertificatePinningConfigurationInitialization() {
    let config = CertificatePinningConfiguration(
      pinnedCertificateHashes: ["hash1", "hash2", "hash3"],
      domains: ["example.com", "api.example.com"]
    )

    XCTAssertEqual(config.pinnedCertificateHashes.count, 3)
    XCTAssertEqual(config.domains.count, 2)
    XCTAssertTrue(config.allowBackupCertificates.rawValue)
  }

  func testCertificatePinningConfigurationCustomSettings() {
    let config = CertificatePinningConfiguration(
      pinnedCertificateHashes: ["hash1"],
      domains: ["secure.example.com"],
      allowBackupCertificates: false,
      validationFailureAction: .warn
    )

    XCTAssertFalse(config.allowBackupCertificates.rawValue)
    if case .warn = config.validationFailureAction {
      // Success
    } else {
      XCTFail("Expected warn action")
    }
  }

  func testCertificatePinningValidationFailureActions() {
    let actions: [CertificatePinningConfiguration.ValidationFailureAction] = [
      .reject, .warn, .allow,
    ]

    for action in actions {
      let config = CertificatePinningConfiguration(
        pinnedCertificateHashes: ["hash"],
        domains: ["example.com"],
        validationFailureAction: action
      )

      switch (action, config.validationFailureAction) {
      case (.reject, .reject), (.warn, .warn), (.allow, .allow):
        break  // Match
      default:
        XCTFail("Validation failure action mismatch")
      }
    }
  }

  func testCertificatePinningWithEmptyHashes() {
    let config = CertificatePinningConfiguration(
      pinnedCertificateHashes: [],
      domains: ["example.com"]
    )

    XCTAssertTrue(config.pinnedCertificateHashes.isEmpty)
  }

  func testCertificatePinningWithEmptyDomains() {
    let config = CertificatePinningConfiguration(
      pinnedCertificateHashes: ["hash1"],
      domains: []
    )

    XCTAssertTrue(config.domains.isEmpty)
  }

  // MARK: - PublicKeyPinningConfiguration Tests

  func testPublicKeyPinningConfigurationInitialization() {
    let config = PublicKeyPinningConfiguration(
      pinnedPublicKeyHashes: ["pkHash1", "pkHash2"],
      domains: ["api.example.com"]
    )

    XCTAssertEqual(config.pinnedPublicKeyHashes.count, 2)
    XCTAssertEqual(config.domains.count, 1)
    XCTAssertTrue(config.requirePinnedKey.rawValue)
  }

  func testPublicKeyPinningConfigurationCustomSettings() {
    let config = PublicKeyPinningConfiguration(
      pinnedPublicKeyHashes: ["pkHash"],
      domains: ["secure.example.com"],
      requirePinnedKey: false,
      validationFailureAction: .allow
    )

    XCTAssertFalse(config.requirePinnedKey.rawValue)
    if case .allow = config.validationFailureAction {
      // Success
    } else {
      XCTFail("Expected allow action")
    }
  }

  func testPublicKeyPinningValidationFailureActions() {
    let actions: [PublicKeyPinningConfiguration.ValidationFailureAction] = [
      .reject, .warn, .allow,
    ]

    for action in actions {
      let config = PublicKeyPinningConfiguration(
        pinnedPublicKeyHashes: ["hash"],
        domains: ["example.com"],
        validationFailureAction: action
      )

      switch (action, config.validationFailureAction) {
      case (.reject, .reject), (.warn, .warn), (.allow, .allow):
        break  // Match
      default:
        XCTFail("Validation failure action mismatch")
      }
    }
  }

  // MARK: - TLSConfiguration Tests

  func testDefaultTLSConfiguration() {
    let config = TLSConfiguration.default

    if case .v1_2 = config.minimumTLSVersion {
      // Success
    } else {
      XCTFail("Expected TLS 1.2 minimum")
    }

    if case .v1_3 = config.maximumTLSVersion {
      // Success
    } else {
      XCTFail("Expected TLS 1.3 maximum")
    }

    XCTAssertTrue(config.validateCertificateChain.rawValue)
    XCTAssertTrue(config.validateHostname.rawValue)
    XCTAssertTrue(config.customCACertificates.isEmpty)
  }

  func testTLSConfigurationCustomSettings() {
    let customCA = CACertificateData(Data("custom-ca-cert".utf8))

    let config = TLSConfiguration(
      minimumTLSVersion: .v1_3,
      maximumTLSVersion: .v1_3,
      validateCertificateChain: false,
      validateHostname: false,
      customCACertificates: [customCA]
    )

    XCTAssertFalse(config.validateCertificateChain.rawValue)
    XCTAssertFalse(config.validateHostname.rawValue)
    XCTAssertEqual(config.customCACertificates.count, 1)
  }

  func testTLSVersionValues() {
    let versions: [TLSConfiguration.TLSVersion] = [.v1_2, .v1_3]

    for version in versions {
      let config = TLSConfiguration(minimumTLSVersion: version)

      switch (version, config.minimumTLSVersion) {
      case (.v1_2, .v1_2), (.v1_3, .v1_3):
        break  // Match
      default:
        XCTFail("TLS version mismatch")
      }
    }
  }

  func testTLSConfigurationWithMultipleCACertificates() {
    let ca1 = CACertificateData(Data("ca-cert-1".utf8))
    let ca2 = CACertificateData(Data("ca-cert-2".utf8))
    let ca3 = CACertificateData(Data("ca-cert-3".utf8))

    let config = TLSConfiguration(
      customCACertificates: [ca1, ca2, ca3]
    )

    XCTAssertEqual(config.customCACertificates.count, 3)
  }

  // MARK: - SSLPinningValidator Tests

  func testSSLPinningValidatorInitialization() {
    let config = SecurityConfiguration.default
    let validator = SSLPinningValidator(securityConfiguration: config)

    XCTAssertNotNil(validator)
  }

  func testSSLPinningValidatorWithCertificatePinning() {
    let certConfig = CertificatePinningConfiguration(
      pinnedCertificateHashes: ["testhash"],
      domains: ["example.com"]
    )
    let config = SecurityConfiguration(certificatePinning: certConfig)
    let validator = SSLPinningValidator(securityConfiguration: config)

    XCTAssertNotNil(validator)
  }

  func testSSLPinningValidatorWithPublicKeyPinning() {
    let pkConfig = PublicKeyPinningConfiguration(
      pinnedPublicKeyHashes: ["testpkhash"],
      domains: ["secure.example.com"]
    )
    let config = SecurityConfiguration(publicKeyPinning: pkConfig)
    let validator = SSLPinningValidator(securityConfiguration: config)

    XCTAssertNotNil(validator)
  }

  // MARK: - Factory Method Tests

  func testWithCertificatePinningFactory() {
    let hashes: Set<CertificateHash> = ["hash1", "hash2"]
    let domains: Set<PinnedDomain> = ["api.example.com"]

    let config = SecurityConfiguration.withCertificatePinning(
      certificateHashes: hashes,
      domains: domains
    )

    XCTAssertNotNil(config.certificatePinning)
    XCTAssertEqual(config.certificatePinning?.pinnedCertificateHashes, hashes)
    XCTAssertEqual(config.certificatePinning?.domains, domains)
  }

  func testWithPublicKeyPinningFactory() {
    let hashes: Set<CertificateHash> = ["pkHash1"]
    let domains: Set<PinnedDomain> = ["secure.example.com"]

    let config = SecurityConfiguration.withPublicKeyPinning(
      publicKeyHashes: hashes,
      domains: domains
    )

    XCTAssertNotNil(config.publicKeyPinning)
    XCTAssertEqual(config.publicKeyPinning?.pinnedPublicKeyHashes, hashes)
    XCTAssertEqual(config.publicKeyPinning?.domains, domains)
  }

  func testStrictSecurityConfiguration() {
    let config = SecurityConfiguration.strict

    if case .v1_3 = config.tlsConfiguration.minimumTLSVersion {
      // Success
    } else {
      XCTFail("Expected TLS 1.3 minimum for strict config")
    }

    if case .v1_3 = config.tlsConfiguration.maximumTLSVersion {
      // Success
    } else {
      XCTFail("Expected TLS 1.3 maximum for strict config")
    }

    XCTAssertTrue(config.tlsConfiguration.validateCertificateChain.rawValue)
    XCTAssertTrue(config.tlsConfiguration.validateHostname.rawValue)
  }

  // MARK: - Edge Case Tests

  func testSecurityConfigurationWithBothPinningTypes() {
    let certConfig = CertificatePinningConfiguration(
      pinnedCertificateHashes: ["certHash"],
      domains: ["cert.example.com"]
    )

    let pkConfig = PublicKeyPinningConfiguration(
      pinnedPublicKeyHashes: ["pkHash"],
      domains: ["pk.example.com"]
    )

    let config = SecurityConfiguration(
      certificatePinning: certConfig,
      publicKeyPinning: pkConfig
    )

    XCTAssertNotNil(config.certificatePinning)
    XCTAssertNotNil(config.publicKeyPinning)
  }

  func testDomainSetOperations() {
    let config = CertificatePinningConfiguration(
      pinnedCertificateHashes: ["hash"],
      domains: ["example.com", "api.example.com", "secure.example.com"]
    )

    XCTAssertTrue(config.domains.contains(PinnedDomain("example.com")))
    XCTAssertTrue(config.domains.contains(PinnedDomain("api.example.com")))
    XCTAssertTrue(config.domains.contains(PinnedDomain("secure.example.com")))
    XCTAssertFalse(config.domains.contains(PinnedDomain("other.com")))
  }

  func testHashSetOperations() {
    let config = CertificatePinningConfiguration(
      pinnedCertificateHashes: ["hash1", "hash2", "hash1"],  // Duplicate
      domains: ["example.com"]
    )

    // Set should deduplicate
    XCTAssertEqual(config.pinnedCertificateHashes.count, 2)
  }

  func testTLSConfigurationMinMaxVersions() {
    let config = TLSConfiguration(
      minimumTLSVersion: .v1_2,
      maximumTLSVersion: .v1_3
    )

    if case .v1_2 = config.minimumTLSVersion {
      // Success
    } else {
      XCTFail("Expected TLS 1.2 minimum")
    }

    if case .v1_3 = config.maximumTLSVersion {
      // Success
    } else {
      XCTFail("Expected TLS 1.3 maximum")
    }
  }

  func testSendableConformance() {
    // These should compile without warnings
    let securityConfig: Sendable = SecurityConfiguration.default
    let tlsConfig: Sendable = TLSConfiguration.default
    let certConfig: Sendable = CertificatePinningConfiguration(
      pinnedCertificateHashes: ["hash"],
      domains: ["example.com"]
    )
    let pkConfig: Sendable = PublicKeyPinningConfiguration(
      pinnedPublicKeyHashes: ["hash"],
      domains: ["example.com"]
    )

    XCTAssertNotNil(securityConfig)
    XCTAssertNotNil(tlsConfig)
    XCTAssertNotNil(certConfig)
    XCTAssertNotNil(pkConfig)
  }
}
