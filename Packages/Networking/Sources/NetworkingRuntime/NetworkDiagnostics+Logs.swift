extension NetworkDiagnostics {
  /// Selects which terminal outcomes are written to unified logging.
  public struct Logs: OptionSet, Sendable {

    public let rawValue: UInt8

    public static let success = Self(rawValue: 1 << 0)

    public static let error = Self(rawValue: 1 << 1)

    public static let none: Self = []

    public init(rawValue: UInt8) {
      self.rawValue = rawValue
    }
  }

  /// Selects the developer-facing representation written to unified logging.
  public enum LogFormat: String, Sendable {

    case curl

    case httpie

    case trace
  }
}
