import MacroTemplateKit
import SwiftSyntax
import SwiftSyntaxBuilder

/// Shared template helpers for HTTP macro implementations.
///
/// Provides reusable Template builders for common HTTP macro patterns.
public enum HTTPMacroTemplate {

  // MARK: - URL Construction

  /// Creates a URL template from path segments.
  ///
  /// - Parameters:
  ///   - baseURL: Base URL identifier
  ///   - pathSegments: Array of path segment templates
  /// - Returns: URL construction template
  public static func buildURL(
    baseURL: Template<Void>,
    pathSegments: [Template<Void>]
  ) -> Template<Void> {
    guard !pathSegments.isEmpty else {
      return baseURL
    }

    return pathSegments.reduce(baseURL) { _, segment in
      .functionCall(
        function: "appendingPathComponent",
        arguments: [(label: nil, value: segment)]
      )
    }
  }

  // MARK: - Request Building

  /// Creates an HTTP request template with method and URL.
  ///
  /// - Parameters:
  ///   - method: HTTP method name
  ///   - url: URL template
  /// - Returns: Request initialization template
  public static func buildRequest(
    method: String,
    url: Template<Void>
  ) -> Template<Void> {
    .functionCall(
      function: "HTTPRequest",
      arguments: [
        (label: "method", value: .literal(.string(method))),
        (label: "url", value: url)
      ]
    )
  }

  // MARK: - Header Addition

  /// Creates a header addition template.
  ///
  /// - Parameters:
  ///   - name: Header name
  ///   - value: Header value template
  /// - Returns: Add header method call template
  public static func addHeader(
    name: String,
    value: Template<Void>
  ) -> Template<Void> {
    .functionCall(
      function: "addHeader",
      arguments: [
        (label: "name", value: .literal(.string(name))),
        (label: "value", value: value)
      ]
    )
  }

  // MARK: - Query Parameter Addition

  /// Creates a query parameter addition template.
  ///
  /// - Parameters:
  ///   - name: Parameter name
  ///   - value: Parameter value template
  /// - Returns: Add query parameter method call template
  public static func addQueryParameter(
    name: String,
    value: Template<Void>
  ) -> Template<Void> {
    .functionCall(
      function: "addQueryParameter",
      arguments: [
        (label: "name", value: .literal(.string(name))),
        (label: "value", value: value)
      ]
    )
  }

  // MARK: - Body Encoding

  /// Creates a JSON body encoding template.
  ///
  /// - Parameter parameterName: Name of the parameter to encode
  /// - Returns: JSON encoding template
  public static func encodeJSONBody(
    parameterName: String
  ) -> Template<Void> {
    .functionCall(
      function: "encode",
      arguments: [(label: nil, value: .variable(parameterName, payload: ()))]
    )
  }

  // MARK: - Response Decoding

  /// Creates a JSON decoding template.
  ///
  /// - Parameters:
  ///   - typeName: Type to decode to
  ///   - data: Data template to decode from
  /// - Returns: Decoding template
  public static func decodeJSON(
    typeName: String,
    from data: Template<Void>
  ) -> Template<Void> {
    .functionCall(
      function: "decode",
      arguments: [
        (label: nil, value: .propertyAccess(
          base: .variable(typeName, payload: ()),
          property: "self"
        )),
        (label: "from", value: data)
      ]
    )
  }

  // MARK: - Rendering

  /// Renders a template to SwiftSyntax expression.
  ///
  /// - Parameter template: Template to render
  /// - Returns: SwiftSyntax expression
  public static func render(_ template: Template<Void>) -> ExprSyntax {
    Renderer.render(template)
  }

  /// Renders a typed HTTP template to SwiftSyntax expression.
  ///
  /// - Parameter template: Typed template to render
  /// - Returns: SwiftSyntax expression
  public static func render<M: HTTPMethodWithBodyConstraint>(
    _ template: TypedHTTPTemplate<M>
  ) -> ExprSyntax {
    template.render()
  }
}
