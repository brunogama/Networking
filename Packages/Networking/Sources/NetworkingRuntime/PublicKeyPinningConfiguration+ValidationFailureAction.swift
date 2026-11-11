extension PublicKeyPinningConfiguration {
  /// Selects whether a key mismatch rejects the connection or falls back to platform trust.
  public enum ValidationFailureAction: Sendable {
    case reject
    case warn
    case allow
  }
}
