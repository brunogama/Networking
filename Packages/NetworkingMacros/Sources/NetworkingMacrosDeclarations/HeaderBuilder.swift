/// Result builder for composing HTTP headers in a declarative syntax.
///
/// `HeaderBuilder` enables a SwiftUI-like DSL for defining HTTP headers
/// in the `@Headers` macro. Headers can reference function parameters or
/// use literal string values.
///
/// ## Usage
///
/// ```swift
/// @Headers {
///     Header("Authorization", "token")
///     Header("Accept", "application/json")
///     Header("X-Custom-Header", "customValue")
/// }
/// func request(token: String, customValue: String) async throws -> Response
/// ```
///
/// ## Result Builder
///
/// The result builder combines multiple `HeaderComponent` instances into
/// an array, preserving the order of declaration.
@resultBuilder
public struct HeaderBuilder {
  /// Combines multiple header components into an array.
  ///
  /// - Parameter components: Variadic list of header components
  /// - Returns: Array of header components in declaration order
  public static func buildBlock(_ components: HeaderComponent...) -> [HeaderComponent] {
    Array(components)
  }
}

// swiftlint:disable identifier_name
/// Creates a header component for use in `@Headers` result builder.
///
/// The second parameter can be either a literal string value or a reference
/// to a function parameter. The macro will determine which at expansion time
/// by checking the function signature.
///
/// ## Parameter vs Literal Detection
///
/// - If `value` matches a function parameter name → `.parameter(value)`
/// - Otherwise → `.literal(value)`
///
/// ## Examples
///
/// ```swift
/// @Headers {
///     H("Content-Type", "application/json")  // Literal
///     H("Authorization", "token")            // Parameter (if token exists)
/// }
/// func request(token: String) async throws -> Response
/// ```
///
/// - Note: The function name `H` is used instead of `Header` to avoid
///   naming conflicts with the existing `Header` struct in `RequestComponents`.
///   Within the `@Headers` macro context, the brevity of `H` is clear and ergonomic.
///
/// - Parameters:
///   - name: The HTTP header name (e.g., "Authorization", "Content-Type")
///   - value: Either a literal value or parameter name
/// - Returns: HeaderComponent for builder composition
public func H(_ name: HeaderName, _ value: HeaderValueReference) -> HeaderComponent {
  // At this stage, we default to .parameter
  // The macro will determine literal vs parameter during expansion
  // based on the function signature
  HeaderComponent(name: name, valueSource: .parameter(value))
}
// swiftlint:enable identifier_name
