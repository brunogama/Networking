import MacroTemplateKit
import SwiftSyntax

// MARK: - Typed HTTP Template

/// Type-safe HTTP template wrapper that enforces method and body constraints.
///
/// The phantom type parameters ensure compile-time validation:
/// - `Method`: The HTTP method (GET, POST, PUT, PATCH, DELETE, etc.)
/// - The body constraint is automatically derived from the method
///
/// ```swift
/// // Allowed: POST methods can have bodies
/// let postTemplate = TypedHTTPTemplate<HTTPMethod.POST>()
///   .withBody(Template.literal("data"))
///
/// // Compile error: GET methods cannot have bodies
/// let getTemplate = TypedHTTPTemplate<HTTPMethod.GET>()
///   .withBody(Template.literal("data"))  // ERROR
/// ```
public struct TypedHTTPTemplate<Method: HTTPMethodWithBodyConstraint>: Sendable {
  /// The underlying untyped template.
  public let template: Template<Void>

  /// The HTTP method name.
  public static var methodName: HTTPMethodName { Method.methodName }

  /// Creates an empty typed template.
  public init() {
    self.template = .arrayLiteral([])
  }

  /// Creates a typed template with an existing template.
  public init(template: Template<Void>) {
    self.template = template
  }

  /// Creates a typed template with a builder.
  public init(@TemplateBuilder<Void> builder: () -> Template<Void>) {
    self.template = builder()
  }
}

// MARK: - URL and Headers (All Methods)

extension TypedHTTPTemplate {
  /// Sets the URL template.
  public func withURL(_ url: Template<Void>) -> TypedHTTPTemplate<Method> {
    TypedHTTPTemplate(
      template: mergeTemplates(
        template,
        .functionCall(function: "url", arguments: [(label: nil, value: url)])
      )
    )
  }

  /// Sets the URL from a string literal.
  public func withURL(_ url: TemplateURL) -> TypedHTTPTemplate<Method> {
    withURL(.literal(.string(url.rawValue)))
  }

  /// Adds a header to the request.
  public func withHeader(
    name: HeaderName,
    value: Template<Void>
  ) -> TypedHTTPTemplate<Method> {
    TypedHTTPTemplate(
      template: mergeTemplates(
        template,
        .functionCall(
          function: "header",
          arguments: [
            (label: "name", value: .literal(.string(name.rawValue))),
            (label: "value", value: value),
          ]
        )
      )
    )
  }

  /// Adds a header with string value.
  public func withHeader(
    name: HeaderName,
    value: HeaderValueReference
  ) -> TypedHTTPTemplate<Method> {
    withHeader(name: name, value: .literal(.string(value.rawValue)))
  }
}

// MARK: - Body (Only for BodyAllowed Methods)

extension TypedHTTPTemplate where Method.Body: BodyAllowedProtocol {
  /// Sets the request body.
  ///
  /// This method is only available for HTTP methods that allow bodies
  /// (POST, PUT, PATCH). Attempting to call this on GET or DELETE
  /// will produce a compile-time error.
  public func withBody(_ body: Template<Void>) -> TypedHTTPTemplate<Method> {
    TypedHTTPTemplate(
      template: mergeTemplates(
        template,
        .functionCall(function: "body", arguments: [(label: nil, value: body)])
      )
    )
  }

  /// Sets the request body from encodable type name.
  public func withEncodableBody(_ bodyParameter: ParameterReference) -> TypedHTTPTemplate<Method> {
    withBody(
      .functionCall(
        function: "encode",
        arguments: [(label: nil, value: .variable(bodyParameter.rawValue, payload: ()))]
      )
    )
  }
}

// MARK: - Query Parameters (All Methods)

extension TypedHTTPTemplate {
  /// Adds a query parameter.
  public func withQuery(
    name: QueryParameterName,
    value: Template<Void>
  ) -> TypedHTTPTemplate<Method> {
    TypedHTTPTemplate(
      template: mergeTemplates(
        template,
        .functionCall(
          function: "query",
          arguments: [
            (label: "name", value: .literal(.string(name.rawValue))),
            (label: "value", value: value),
          ]
        )
      )
    )
  }
}

// MARK: - Rendering

extension TypedHTTPTemplate {
  /// Renders the template to SwiftSyntax ExprSyntax.
  public func render() -> ExprSyntax {
    Renderer.render(template)
  }
}

// MARK: - Private Helpers

private func mergeTemplates(_ existing: Template<Void>, _ new: Template<Void>) -> Template<Void> {
  switch existing {
  case .arrayLiteral(let elements):
    return .arrayLiteral(elements + [new])
  default:
    return .arrayLiteral([existing, new])
  }
}
