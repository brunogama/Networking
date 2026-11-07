extension TLSConfiguration {
  /// Supported TLS protocol versions.
  public enum TLSVersion: Sendable {
    case tls12
    case tls13
  }
}
