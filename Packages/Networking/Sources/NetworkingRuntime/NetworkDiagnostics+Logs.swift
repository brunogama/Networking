extension NetworkDiagnostics {
  /// Selects which terminal outcomes are written to unified logging.
  public struct Logs: OptionSet, Sendable {
    /// The raw bit set backing this selection.
    public let rawValue: UInt8

    /// Writes a rendered trace after a successful HTTP response.
    public static let success = Self(rawValue: 1 << 0)

    /// Writes a rendered trace after a transport or HTTP failure.
    public static let error = Self(rawValue: 1 << 1)

    /// Disables diagnostic log output while preserving trace retention.
    public static let none: Self = []

    /// Creates a selection from its raw bit representation.
    public init(rawValue: UInt8) {
      self.rawValue = rawValue
    }
  }

  /// Selects the developer-facing representation written to unified logging.
  public enum LogFormat: String, Sendable {
    /// Emits a sanitized cURL command suitable for copying and adapting.
    case curl

    /// Emits a sanitized HTTPie command suitable for copying and adapting.
    case httpie

    /// Emits the complete sanitized trace as pretty-printed JSON.
    case trace
  }
}
