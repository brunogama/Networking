import Foundation
import XCTest

#if canImport(CommonCrypto)
import CommonCrypto
#endif

#if canImport(Security)
import Security

@testable import NetworkingRuntime
import NetworkingCore

enum SSLPinningTestFixtures {
  static let validHost = "valid.example.com"
  static let invalidHost = "other.example.com"
  static let leafSPKIHash =
    "026c3eb10a29d791a25c980ac17fc46d10ffa08626cdc241d0488ea265f8ce5c"

  static func makeTrust() throws -> SecTrust {
    let certificates = [try leafCertificate(), try rootCertificate()]
    var trust: SecTrust?
    let status = SecTrustCreateWithCertificates(
      certificates as CFArray,
      SecPolicyCreateBasicX509(),
      &trust
    )

    XCTAssertEqual(status, errSecSuccess)
    return try XCTUnwrap(trust)
  }

  static func leafCertificate() throws -> SecCertificate {
    try certificate(from: leafCertificateBase64)
  }

  static func rootCertificate() throws -> SecCertificate {
    try certificate(from: rootCertificateBase64)
  }

  static func rootCertificateData() throws -> Data {
    try XCTUnwrap(Data(base64Encoded: rootCertificateBase64))
  }

  static func anchoredTLSValidator(validateHostname: Bool = true) throws -> SSLPinningValidator {
    SSLPinningValidator(
      securityConfiguration: SecurityConfiguration(
        tlsConfiguration: try anchoredTLSConfiguration(validateHostname: validateHostname)
      )
    )
  }

  static func certificatePinningValidator(
    pinnedCertificateHashes: [CertificateHash],
    domains: [PinnedDomain],
    allowBackupCertificates: Bool = false,
    includeRootAnchor: Bool = true
  ) throws -> SSLPinningValidator {
    SSLPinningValidator(
      securityConfiguration: SecurityConfiguration(
        certificatePinning: CertificatePinningConfiguration(
          pinnedCertificateHashes: Set(pinnedCertificateHashes),
          domains: Set(domains),
          allowBackupCertificates: BackupCertificateAllowance(rawValue: allowBackupCertificates)
        ),
        tlsConfiguration: try includeRootAnchor ? anchoredTLSConfiguration() : TLSConfiguration()
      )
    )
  }

  static func publicKeyPinningValidator(
    pinnedPublicKeyHashes: [CertificateHash],
    domains: [PinnedDomain]
  ) throws -> SSLPinningValidator {
    SSLPinningValidator(
      securityConfiguration: SecurityConfiguration(
        tlsConfiguration: try anchoredTLSConfiguration(),
        publicKeyPinning: PublicKeyPinningConfiguration(
          pinnedPublicKeyHashes: Set(pinnedPublicKeyHashes),
          domains: Set(domains)
        )
      )
    )
  }

  static func certificateHash(for certificate: SecCertificate) -> CertificateHash {
    CertificateHash(
      SSLPinningValidator(securityConfiguration: .default).sha256Hash(of: certificate)
    )
  }

  static func rawPublicKeyHash(for certificate: SecCertificate) throws -> CertificateHash {
    let publicKey = try XCTUnwrap(SecCertificateCopyKey(certificate))
    let publicKeyData = try XCTUnwrap(SecKeyCopyExternalRepresentation(publicKey, nil) as Data?)
    return CertificateHash(sha256Hex(of: publicKeyData))
  }

  private static func certificate(from base64: String) throws -> SecCertificate {
    let certificateData = try XCTUnwrap(Data(base64Encoded: base64))
    return try XCTUnwrap(SecCertificateCreateWithData(nil, certificateData as CFData))
  }

  private static func anchoredTLSConfiguration(
    validateHostname: Bool = true
  ) throws -> TLSConfiguration {
    TLSConfiguration(
      validateHostname: TLSHostnameValidationFlag(rawValue: validateHostname),
      customCACertificates: [CACertificateData(try rootCertificateData())]
    )
  }

  private static func sha256Hex(of data: Data) -> String {
    var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
    data.withUnsafeBytes { buffer in
      guard let baseAddress = buffer.baseAddress else {
        return
      }

      CC_SHA256(baseAddress, CC_LONG(buffer.count), &digest)
    }
    return digest.map { String(format: "%02x", $0) }.joined()
  }

  private static let rootCertificateBase64 = [
    "MIIDQTCCAimgAwIBAgIUOeLxsEHRHNq9I+UNCYQIqzGh3bwwDQYJKoZIhvcNAQELBQAwKDEmMCQG",
    "A1UEAwwdTW9kZXJuTmV0d29ya2luZyBUZXN0IFJvb3QgQ0EwHhcNMjYwMzEwMjMxNjAxWhcNMzYw",
    "MzA3MjMxNjAxWjAoMSYwJAYDVQQDDB1Nb2Rlcm5OZXR3b3JraW5nIFRlc3QgUm9vdCBDQTCCASIw",
    "DQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALRcqDzeDZXInDEfZOYONY/xUN/SuupQhw84Ygre",
    "OYZ5ldplDo79qg3zdUGHGZefm7aKb9obDQ9zbs6brozzCbWSqz7htUBqCen6gS/WtR7H6nSXrMsn",
    "zckhcDM+d9X457AttjNMe2N3zy2S0VBdFQ5oDwWQkO8pKw5dcVraNtCY+W6jQnLnmp5I4lRBwoo9",
    "AZZENW+kE7dKcBezupE/BfcPU8w9Pvh2sMyQh49DSdexF6zXiF2HN+tRgkNYoDnLzPTMnwhO87Yx",
    "KDGPPH37J4w4ictobn7RvILtH2fVnUUNzCTKCV2SYHicJ8+mgBqJCh+x3wO9VCQDPvC+/XV1qoUC",
    "AwEAAaNjMGEwHQYDVR0OBBYEFHCYXK9oIYPtv7zAFLFwQNQHxFOBMB8GA1UdIwQYMBaAFHCYXK9o",
    "IYPtv7zAFLFwQNQHxFOBMA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgEGMA0GCSqGSIb3",
    "DQEBCwUAA4IBAQAW9BqkZwt/YBNkHgMkjEIpGTtGOQ+K7qOq1+MEKiHn1Qkn7xrNWOORMm99k/aS",
    "IjtrgfxECZnqgD6FgUZuVN/cH9lPXQXA5FErXeXwiD9unoSyCHeh1moa8Lll1+6IswNqBE+KJDsh",
    "RHrfPHK5zaV/dDaiw8cM12RMV0HedYBFG6Xb2aGlIVoN/UvOHOrPayCNLH0drKAUaYnthn5SqMyz",
    "JS/hlzf04DZeMucwLRs2K8g+J1h/qs/uVMkCv6xvp4jFwH2mo/F19CoZJw7H5GkFsXqmI2hyS3GX",
    "QLWlQLm6FIBKWDd2WRLsksKcP040TZlf8YYzcWlfmMM4AIrbCb3F",
  ].joined()

  private static let leafCertificateBase64 = [
    "MIIDZzCCAk+gAwIBAgIUQGyal6jXCi7t260SI39Zo2SmCY4wDQYJKoZIhvcNAQELBQAwKDEmMCQG",
    "A1UEAwwdTW9kZXJuTmV0d29ya2luZyBUZXN0IFJvb3QgQ0EwHhcNMjYwMzEwMjMxNjAxWhcNMjcw",
    "MzEwMjMxNjAxWjAcMRowGAYDVQQDDBF2YWxpZC5leGFtcGxlLmNvbTCCASIwDQYJKoZIhvcNAQEB",
    "BQADggEPADCCAQoCggEBAJfvYwuFFg++IDdBMW9ymcptJ6OXzIKXFN1ocWuzoa3Ckw4CFiAtxp+W",
    "aCjYGzsamcanSknALNQ7EkrmYGh9tCJ6yRATfzP0qJjDzmyMUBipf4tQm/i5GeoYS0ZQWUeMD8UU",
    "m3F4ZKTeaeNxg6Raf9OCVUBjxmK2HW6/84vgldjk1UBpOlf2rUP9/JnrYghLQuSLSLpC3E5IePZB",
    "T/PWuWKJuLbDZZPra1tv78+18sfW9k8D3+VPl/OiZkaPSikl7rfX19Dk5HUE8J+yIEog9kJVhWSh",
    "0vImhYdXlqkhIqzq8A2fausVVPzIs86uNByvwdX4VL0SKre48kf7woiolwkCAwEAAaOBlDCBkTAc",
    "BgNVHREEFTATghF2YWxpZC5leGFtcGxlLmNvbTAMBgNVHRMBAf8EAjAAMA4GA1UdDwEB/wQEAwIF",
    "oDATBgNVHSUEDDAKBggrBgEFBQcDATAdBgNVHQ4EFgQUC6DWvYWkONhCLNeDisXG48YGDtIwHwYD",
    "VR0jBBgwFoAUcJhcr2ghg+2/vMAUsXBA1AfEU4EwDQYJKoZIhvcNAQELBQADggEBAHq8u2a+OOd7",
    "PypG9iL0g47aTA4uqhbKUIQ47SkOkIXsZTlDwBkEAvO0njtvvSEL+woidJmcQWgrMg4pwifwIE9t",
    "oyeg9ieZr8PolT4K8EOjX5pV+629cocqETRsw+LJYlF42sYqGycilIOcLU9LJKupPJ51vgE29ZhS",
    "qzZK9JAn5FJTn2yifV6aKW1Cd1o8Dk5hal+ZuU5trsGIPAM/0tuThEN1Yr0uH0N90EgAvG5Ua+7k",
    "Frtf415nm9jFnMamxZz5YtcEbvHLwgeemMCDEJS2+u2HU/0u1sMlK6MZxyN7Cvm2/GM0cM/GzEwI",
    "GhYD6Q/qlMiXooJt6QYZ/IaGCTY=",
  ].joined()
}

#endif
