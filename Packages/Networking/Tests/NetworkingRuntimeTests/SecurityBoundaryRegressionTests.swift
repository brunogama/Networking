import Foundation
import NetworkingCore
import Testing

@testable import NetworkingRuntime

struct SecurityBoundaryRegressionTests {
  @Test(arguments: ["Bad Name", "X-É", "X\r\nInjected", ""])
  func rejectsInvalidHeaderNames(name: String) async throws {
    #expect(!HeaderSecurity.isValidHeaderName(HTTPHeaderName(name)).rawValue)
    let request = HTTPRequest(
      method: .get,
      url: try #require(URL(string: "https://example.com/")),
      headers: [name: "value"]
    )
    await #expect(throws: HTTPError.self) {
      try await HeaderSecurityMiddleware().modifyRequest(request)
    }
  }

  @Test func headerAndAuthenticationMiddlewarePreserveIdentity() async throws {
    let request = HTTPRequest(
      method: .get,
      url: try #require(URL(string: "https://example.com/")),
      headers: ["X-Test": "value"]
    )
    let secured = try await HeaderSecurityMiddleware().modifyRequest(request)
    #expect(secured.id == request.id)
    let provider = MemoryTokenProvider(initialToken: "token", refreshHandler: { "refreshed" })
    let auth = AuthenticationMiddleware(
      configuration: .init(),
      tokenProvider: provider,
      client: NetworkClient()
    )
    let authenticated = try await auth.modifyRequest(secured)
    #expect(authenticated.id == request.id)
    #expect(authenticated.headers["Authorization"] == "Bearer token")
  }

  #if canImport(Security)
  @Test func multiplePinsAcceptAnyMatchingLeaf() throws {
    let leaf = try SSLPinningTestFixtures.leafCertificate()
    let validator = try SSLPinningTestFixtures.certificatePinningValidator(
      pinnedCertificateHashes: [SSLPinningTestFixtures.certificateHash(for: leaf), "nonmatching"],
      domains: [PinnedDomain(SSLPinningTestFixtures.validHost.uppercased())]
    )
    #expect(
      validator.validationDecision(
        serverTrust: try SSLPinningTestFixtures.makeTrust(),
        host: SSLPinningTestFixtures.validHost
      ) == .useCredential
    )
  }

  @Test func combinedPoliciesCannotSkipPublicKeyValidation() throws {
    let leaf = try SSLPinningTestFixtures.leafCertificate()
    let certificateValidator = try SSLPinningTestFixtures.certificatePinningValidator(
      pinnedCertificateHashes: [SSLPinningTestFixtures.certificateHash(for: leaf)],
      domains: [PinnedDomain(SSLPinningTestFixtures.validHost)]
    )
    let options = certificateValidator.securityConfiguration
    let validator = SSLPinningValidator(
      securityConfiguration: SecurityConfiguration(
        certificatePinning: options.certificatePinning,
        tlsConfiguration: options.tlsConfiguration,
        publicKeyPinning: PublicKeyPinningConfiguration(
          pinnedPublicKeyHashes: ["nonmatching"],
          domains: [PinnedDomain(SSLPinningTestFixtures.validHost)]
        )
      )
    )
    #expect(
      validator.validationDecision(
        serverTrust: try SSLPinningTestFixtures.makeTrust(),
        host: SSLPinningTestFixtures.validHost
      ) == .rejectProtectionSpace
    )
  }
  #endif
}
