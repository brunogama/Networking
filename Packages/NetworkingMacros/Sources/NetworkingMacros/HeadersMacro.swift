import SwiftSyntax
import SwiftSyntaxMacros

/// Macro implementation for @Headers attached macro with result builder syntax.
///
/// The @Headers macro is a "marker macro" that parses the result builder closure,
/// validates header configurations, but doesn't generate any peer code. HTTP method
/// macros detect this attribute and use it to generate header addition code.
public struct HeadersMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    // 1. Validate macro is applied to a function
    guard declaration.is(FunctionDeclSyntax.self) else {
      MacroHelpers.emitError(
        "@Headers can only be applied to functions",
        node: node,
        context: context
      )
      return []
    }

    guard let headers = extractHeaders(from: node) else {
      MacroHelpers.emitError(
        """
        @Headers requires result builder closure: \
        @Headers { H(.named(\"name\"), .literal(\"value\")) }
        """,
        node: node,
        context: context
      )
      return []
    }

    emitEmptyHeadersWarningIfNeeded(headers, node: node, context: context)
    validateHeaderNames(headers, node: node, context: context)
    return []
  }

  /// Extracts parsed headers from the @Headers result builder closure.
  ///
  /// Parses syntax like:
  /// ```
  /// @Headers {
  ///     H(.named("Authorization"), .parameter("token"))
  ///     H(.named("Accept"), .literal("application/json"))
  /// }
  /// ```
  ///
  /// - Parameter node: The attribute syntax node
  /// - Returns: Array of parsed headers, or nil if parsing fails
  private static func extractHeaders(
    from node: AttributeSyntax
  ) -> [ParsedHeader]? {
    guard let closure = HeaderMacroParser.closure(from: node) else {
      return nil
    }

    return HeaderMacroParser.parseHeaders(from: closure)
  }

  private static func emitEmptyHeadersWarningIfNeeded(
    _ headers: [ParsedHeader],
    node: AttributeSyntax,
    context: some MacroExpansionContext
  ) {
    guard headers.isEmpty else {
      return
    }

    MacroHelpers.emitWarning(
      "@Headers closure is empty - no headers will be added",
      node: Syntax(node),
      context: context
    )
  }

  private static func validateHeaderNames(
    _ headers: [ParsedHeader],
    node: AttributeSyntax,
    context: some MacroExpansionContext
  ) {
    for header in headers where header.name.contains("\r") || header.name.contains("\n") {
      MacroHelpers.emitError(
        """
        Header name '\(header.name)' contains CRLF characters (security risk). \
        Header names must not contain \\r or \\n characters.
        """,
        node: Syntax(node),
        context: context
      )
    }
  }

}

// MARK: - Additional Error Cases

extension MacroExpansionError {
  static func invalidHeadersSyntax(_ message: String) -> MacroExpansionError {
    .invalidPathTemplate(
      EndpointPath(message),
      suggestion: MacroDiagnosticText(
        "Use @Headers { H(.named(\"name\"), .literal(\"value\")) }"
      )
    )
  }
}
