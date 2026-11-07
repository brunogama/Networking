/// Invalid OTLP transport configuration.
public enum OTLPConfigurationError: Error, Sendable, Equatable {
  /// The endpoint is not an HTTP collector base URL without credentials, query, or fragment.
  case invalidEndpoint
  /// The timeout must be finite and positive.
  case invalidTimeout
}
