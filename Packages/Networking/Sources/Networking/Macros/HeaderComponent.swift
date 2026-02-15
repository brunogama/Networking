/// Represents a single HTTP header with its name and value source.
///
/// Used in conjunction with `@Headers` macro and `HeaderBuilder` to compose
/// HTTP headers in a declarative, type-safe manner.
///
/// ## Value Sources
///
/// Headers can have two types of value sources:
/// - `.parameter(String)`: Value comes from a function parameter
/// - `.literal(String)`: Value is a literal string constant
///
/// ## Usage
///
/// ```swift
/// @Headers {
///     H("Authorization", "token")          // Parameter reference
///     H("Content-Type", "application/json") // Literal value
/// }
/// func request(token: String) async throws -> Response
/// ```
public struct HeaderComponent: Sendable {
  /// The HTTP header name (e.g., "Authorization", "Content-Type")
  public let name: String

  /// The source of the header value (parameter reference or literal)
  public let valueSource: ValueSource

  /// Determines whether header value comes from a function parameter or is a literal.
  public enum ValueSource: Sendable {
    /// Value comes from a function parameter with the given name
    case parameter(String)

    /// Value is a literal string constant
    case literal(String)
  }

  /// Creates a new header component.
  ///
  /// - Parameters:
  ///   - name: The HTTP header name
  ///   - valueSource: The source of the header value
  public init(name: String, valueSource: ValueSource) {
    self.name = name
    self.valueSource = valueSource
  }
}
