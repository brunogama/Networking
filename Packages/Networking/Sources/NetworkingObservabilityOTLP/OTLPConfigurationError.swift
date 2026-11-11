/// Invalid OTLP transport configuration.
public enum OTLPConfigurationError: Error, Sendable, Equatable {

  case invalidEndpoint

  case invalidTimeout
}
