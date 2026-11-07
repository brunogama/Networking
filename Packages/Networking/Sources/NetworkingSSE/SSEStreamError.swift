/// A stream buffering, configuration, or response-size failure.
public enum SSEStreamError: Error, Sendable {
  case bufferOverflow
  case invalidConfiguration
  case responseTooLarge
}
