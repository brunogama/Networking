extension CertificatePinningConfiguration {
  /// Selects whether a pin mismatch rejects the connection or falls back to platform trust.
  public enum ValidationFailureAction: Sendable {
    case reject
    case warn
    case allow
  }
}
