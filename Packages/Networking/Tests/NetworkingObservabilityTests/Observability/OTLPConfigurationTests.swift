import Foundation
import NetworkingCore
import NetworkingObservabilityOTLP
import Testing

@Suite("OTLP configuration boundaries")
struct OTLPConfigurationTests {
  @Test(
    "Only valid HTTP collector base URLs are accepted",
    arguments: [
      "file:///tmp/collector", "https://user:secret@example.com",
      "https://example.com?token=secret",
    ]
  )
  func rejectsInvalidEndpoint(_ address: String) throws {
    let configuration = OTLPConfiguration(
      endpoint: HTTPRequestURL(try #require(URL(string: address)))
    )
    #expect(throws: OTLPConfigurationError.invalidEndpoint) { try configuration.validate() }
  }

  @Test("Nonfinite and nonpositive timeouts are rejected", arguments: [0.0, -1.0, Double.infinity])
  func rejectsInvalidTimeout(_ timeout: Double) throws {
    let configuration = OTLPConfiguration(
      endpoint: HTTPRequestURL(try #require(URL(string: "https://collector.example"))),
      timeout: RequestTimeout(timeout)
    )
    #expect(throws: OTLPConfigurationError.invalidTimeout) { try configuration.validate() }
  }
}
