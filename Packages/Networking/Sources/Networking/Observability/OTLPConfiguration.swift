import Foundation

/// Protocol supported by OTLP exporters.
public enum OTLPProtocol: String, Sendable {
  case http = "http/protobuf"
  case grpc = "grpc"  // Future: requires grpc-swift
}

/// Configuration for OpenTelemetry Protocol (OTLP) exporters.
///
/// Use the builder pattern to configure OTLP export settings:
/// ```swift
/// let config = OTLPConfiguration(
///   endpoint: URL(string: "http://localhost:4318")!,
///   headers: ["Authorization": "Bearer token"],
///   resource: OTLPResource(serviceName: "my-app")
/// )
/// ```
///
/// ## Configuration from Environment Variables
///
/// You can create configuration from standard OTEL environment variables:
/// ```swift
/// if let config = OTLPConfiguration.fromEnvironment() {
///   // Use environment-based configuration
/// }
/// ```
///
/// The following environment variables are supported:
/// - `OTEL_EXPORTER_OTLP_ENDPOINT`: Collector URL (required)
/// - `OTEL_EXPORTER_OTLP_HEADERS`: Comma-separated key=value pairs
/// - `OTEL_SERVICE_NAME`: Service name
/// - `OTEL_SERVICE_VERSION`: Service version
public struct OTLPConfiguration: Sendable {
  /// The OTLP collector endpoint URL (e.g., http://localhost:4318)
  public let endpoint: URL

  /// Custom headers for authentication (e.g., Authorization, API keys)
  public let headers: [String: String]

  /// Request timeout for OTLP exports
  public let timeout: TimeInterval

  /// Maximum number of spans/metrics to batch before export
  public let batchSize: Int

  /// How often to flush batched data (seconds)
  public let flushInterval: TimeInterval

  /// Protocol to use for OTLP export
  public let `protocol`: OTLPProtocol

  /// Service resource attributes
  public let resource: OTLPResource

  /// Attributes to redact from spans/metrics (security)
  public let redactedAttributes: Set<String>

  /// Creates a new OTLP configuration with the specified parameters.
  ///
  /// - Parameters:
  ///   - endpoint: The OTLP collector endpoint URL
  ///   - headers: Custom headers for authentication (default: empty)
  ///   - timeout: Request timeout in seconds (default: 10.0)
  ///   - batchSize: Maximum batch size before export (default: 512)
  ///   - flushInterval: Flush interval in seconds (default: 5.0)
  ///   - protocol: OTLP protocol to use (default: .http)
  ///   - resource: Service resource attributes (default: auto-detected)
  ///   - redactedAttributes: Attributes to redact (default: security-sensitive attributes)
  public init(
    endpoint: URL,
    headers: [String: String] = [:],
    timeout: TimeInterval = 10.0,
    batchSize: Int = 512,
    flushInterval: TimeInterval = 5.0,
    protocol: OTLPProtocol = .http,
    resource: OTLPResource = OTLPResource(),
    redactedAttributes: Set<String> = Self.defaultRedactedAttributes
  ) {
    self.endpoint = endpoint
    self.headers = headers
    self.timeout = timeout
    self.batchSize = batchSize
    self.flushInterval = flushInterval
    self.protocol = `protocol`
    self.resource = resource
    self.redactedAttributes = redactedAttributes
  }

  /// Default attributes that should be redacted for security.
  ///
  /// These attributes typically contain sensitive information and should not be
  /// exported to telemetry backends to prevent credential leakage.
  public static let defaultRedactedAttributes: Set<String> = [
    "http.request.header.authorization",
    "http.request.header.cookie",
    "http.request.header.x-api-key",
    "user.password",
    "user.token",
  ]
}

// MARK: - Environment-Based Configuration

extension OTLPConfiguration {
  /// Creates configuration from environment variables (OTEL_* convention).
  ///
  /// This factory method reads standard OpenTelemetry environment variables:
  /// - `OTEL_EXPORTER_OTLP_ENDPOINT`: Collector URL
  /// - `OTEL_EXPORTER_OTLP_HEADERS`: Comma-separated key=value pairs
  /// - `OTEL_SERVICE_NAME`: Service name
  /// - `OTEL_SERVICE_VERSION`: Service version
  ///
  /// - Returns: Configuration if `OTEL_EXPORTER_OTLP_ENDPOINT` is set, `nil` otherwise.
  ///
  /// ## Example
  ///
  /// ```bash
  /// export OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4318"
  /// export OTEL_EXPORTER_OTLP_HEADERS="Authorization=Bearer token, X-API-Key=secret"
  /// export OTEL_SERVICE_NAME="my-ios-app"
  /// export OTEL_SERVICE_VERSION="1.2.3"
  /// ```
  ///
  /// ```swift
  /// if let config = OTLPConfiguration.fromEnvironment() {
  ///   // Use environment-based configuration
  /// }
  /// ```
  public static func fromEnvironment() -> OTLPConfiguration? {
    guard let endpointString = ProcessInfo.processInfo.environment["OTEL_EXPORTER_OTLP_ENDPOINT"],
      let endpoint = URL(string: endpointString)
    else {
      return nil
    }

    let headers = parseHeaders(
      ProcessInfo.processInfo.environment["OTEL_EXPORTER_OTLP_HEADERS"])
    let serviceName = ProcessInfo.processInfo.environment["OTEL_SERVICE_NAME"] ?? "unknown"
    let serviceVersion = ProcessInfo.processInfo.environment["OTEL_SERVICE_VERSION"]

    let resource = OTLPResource(
      serviceName: serviceName,
      serviceVersion: serviceVersion
    )

    return OTLPConfiguration(
      endpoint: endpoint,
      headers: headers,
      resource: resource
    )
  }

  /// Parses comma-separated key=value header pairs.
  ///
  /// - Parameter headerString: Comma-separated header string (e.g., "key1=value1, key2=value2")
  /// - Returns: Dictionary of header key-value pairs
  private static func parseHeaders(_ headerString: String?) -> [String: String] {
    guard let headerString = headerString else { return [:] }
    var headers: [String: String] = [:]
    for pair in headerString.split(separator: ",") {
      let parts = pair.split(separator: "=", maxSplits: 1)
      if parts.count == 2 {
        headers[String(parts[0]).trimmingCharacters(in: .whitespaces)] =
          String(parts[1]).trimmingCharacters(in: .whitespaces)
      }
    }
    return headers
  }
}

// MARK: - Validation

extension OTLPConfiguration {
  /// Validates configuration is usable for OTLP export.
  ///
  /// - Throws: `OTLPConfigurationError` if validation fails
  ///
  /// ## Validation Rules
  ///
  /// - Endpoint must use http or https scheme
  /// - Timeout must be positive
  /// - Batch size must be positive
  public func validate() throws {
    guard endpoint.scheme == "http" || endpoint.scheme == "https" else {
      throw OTLPConfigurationError.invalidEndpoint(
        "Endpoint must use http or https scheme")
    }
    guard timeout > 0 else {
      throw OTLPConfigurationError.invalidTimeout("Timeout must be positive")
    }
    guard batchSize > 0 else {
      throw OTLPConfigurationError.invalidBatchSize("Batch size must be positive")
    }
  }
}

/// Errors that can occur during OTLP configuration validation.
public enum OTLPConfigurationError: Error, Sendable {
  /// The endpoint URL is invalid or uses an unsupported scheme.
  case invalidEndpoint(String)

  /// The timeout value is invalid (must be positive).
  case invalidTimeout(String)

  /// The batch size is invalid (must be positive).
  case invalidBatchSize(String)
}
