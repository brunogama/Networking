@testable import NetworkingObservability
import NetworkingRuntime
import NetworkingDSL
import NetworkingObservabilityOTLP
import NetworkingTesting
import Testing

@Suite("OTLP Configuration Tests")
struct OTLPConfigurationTests {
  // MARK: - Initialization Tests

  @Test("Creates configuration with default values")
  func initWithDefaults() throws {
    let endpoint = URL(string: "http://localhost:4318")!
    let config = OTLPConfiguration(endpoint: endpoint)

    #expect(config.endpoint.rawValue == endpoint)
    #expect(config.headers.isEmpty == true)
    #expect(config.timeout == 10.0)
    #expect(config.batchSize == 512)
    #expect(config.flushInterval == 5.0)
    #expect(config.protocol == .http)
    #expect(config.resource.serviceName == "unknown")
  }

  @Test("Creates configuration with custom values")
  func initWithCustomValues() throws {
    let endpoint = URL(string: "https://otel.example.com:4318")!
    let resource = OTLPResource(
      serviceName: "my-app",
      serviceVersion: "1.0.0",
      deploymentEnvironment: "production"
    )

    let config = OTLPConfiguration(
      endpoint: endpoint,
      headers: ["Authorization": "Bearer token"],
      timeout: 30.0,
      batchSize: 1000,
      flushInterval: 10.0,
      protocol: .http,
      resource: resource
    )

    #expect(config.endpoint.rawValue == endpoint)
    #expect(config.headers["Authorization"] == "Bearer token")
    #expect(config.timeout == 30.0)
    #expect(config.batchSize == 1000)
    #expect(config.resource.serviceName == "my-app")
    #expect(config.resource.serviceVersion == "1.0.0")
    #expect(config.resource.deploymentEnvironment == "production")
  }

  // MARK: - Validation Tests

  @Test("Validates HTTP endpoint scheme")
  func validateHttpEndpoint() throws {
    let endpoint = URL(string: "http://localhost:4318")!
    let config = OTLPConfiguration(endpoint: endpoint)
    #expect(throws: Never.self) {
      try config.validate()
    }
  }

  @Test("Validates HTTPS endpoint scheme")
  func validateHttpsEndpoint() throws {
    let endpoint = URL(string: "https://otel.example.com:4318")!
    let config = OTLPConfiguration(endpoint: endpoint)
    #expect(throws: Never.self) {
      try config.validate()
    }
  }

  @Test("Rejects invalid endpoint scheme")
  func rejectInvalidScheme() throws {
    let endpoint = URL(string: "ftp://localhost:4318")!
    let config = OTLPConfiguration(endpoint: endpoint)
    #expect(throws: OTLPConfigurationError.self) {
      try config.validate()
    }
  }

  @Test("Rejects negative timeout")
  func rejectNegativeTimeout() throws {
    let endpoint = URL(string: "http://localhost:4318")!
    let config = OTLPConfiguration(endpoint: endpoint, timeout: -1.0)
    #expect(throws: OTLPConfigurationError.self) {
      try config.validate()
    }
  }

  @Test("Rejects zero batch size")
  func rejectZeroBatchSize() throws {
    let endpoint = URL(string: "http://localhost:4318")!
    let config = OTLPConfiguration(endpoint: endpoint, batchSize: 0)
    #expect(throws: OTLPConfigurationError.self) {
      try config.validate()
    }
  }

  // MARK: - Environment Parsing Tests

  @Test("Parses configuration from environment")
  func parseFromEnvironment() throws {
    // Note: This test requires setting env vars, which is tricky in unit tests
    // For now, test that nil is returned when env vars are not set
    let config = OTLPConfiguration.fromEnvironment()
    #expect(config == nil)  // No OTEL_EXPORTER_OTLP_ENDPOINT set
  }

  // MARK: - Redacted Attributes Tests

  @Test("Default redacted attributes include sensitive headers")
  func defaultRedactedAttributes() {
    let defaults = OTLPConfiguration.defaultRedactedAttributes
    #expect(defaults.contains("http.request.header.authorization"))
    #expect(defaults.contains("http.request.header.cookie"))
    #expect(defaults.contains("http.request.header.x-api-key"))
  }
}
