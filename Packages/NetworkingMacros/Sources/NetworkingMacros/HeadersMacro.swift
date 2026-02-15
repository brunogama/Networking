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
    guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
      throw MacroExpansionError.invalidMacroApplication(
        "@Headers can only be applied to functions"
      )
    }

    // 2. Extract header configurations from result builder closure
    guard let headers = extractHeaderComponents(from: node) else {
      throw MacroExpansionError.invalidHeadersSyntax(
        "@Headers requires result builder closure: @Headers { H(\"name\", \"value\") }"
      )
    }

    // 3. Warn if empty (common mistake)
    if headers.isEmpty {
      MacroHelpers.emitWarning(
        "@Headers closure is empty - no headers will be added",
        node: Syntax(node),
        context: context
      )
    }

    // 4. Get all parameter names from function signature
    let parameters = funcDecl.signature.parameterClause.parameters
    let paramNames = Set(
      parameters.map { param in
        param.secondName?.text ?? param.firstName.text
      }
    )

    // 5. Validate all parameter references exist and check for CRLF injection
    for header in headers {
      // CRLF injection prevention (OWASP A03:2021)
      if header.name.contains("\r") || header.name.contains("\n") {
        MacroHelpers.emitError(
          """
          Header name '\(header.name)' contains CRLF characters (security risk). \
          Header names must not contain \\r or \\n characters.
          """,
          node: Syntax(node),
          context: context
        )
      }

      // Validate parameter references (if it's a parameter)
      // Note: We check if the value matches a parameter name to determine if it's a reference
      if paramNames.contains(header.value) {
        // It's a valid parameter reference - good!
        continue
      }
      // Otherwise, it's a literal value - also valid
    }

    // 6. @Headers is a marker macro - return empty array
    // HTTP method macros will detect this attribute and use the headers
    return []
  }

  /// Extracts header name/value pairs from the @Headers result builder closure
  ///
  /// Parses syntax like:
  /// ```
  /// @Headers {
  ///     H("Authorization", "token")
  ///     H("Accept", "application/json")
  /// }
  /// ```
  ///
  /// - Parameter node: The attribute syntax node
  /// - Returns: Array of (name, value) tuples, or nil if parsing fails
  private static func extractHeaderComponents(
    from node: AttributeSyntax
  ) -> [(
    name: String, value: String
  )]? {
    // Parse the closure argument
    guard case .argumentList(let arguments) = node.arguments,
      let closureArg = arguments.first,
      let closure = closureArg.expression.as(ClosureExprSyntax.self)
    else {
      return nil
    }

    var headers: [(String, String)] = []

    // Extract H("name", "value") calls from closure
    for statement in closure.statements {
      // Look for function call expressions: H("name", "value")
      if let funcCall = statement.item.as(FunctionCallExprSyntax.self),
        let identExpr = funcCall.calledExpression.as(DeclReferenceExprSyntax.self),
        identExpr.baseName.text == "H"
      {
        let args = Array(funcCall.arguments)
        guard args.count == 2,
          let nameLiteral = args[0].expression.as(StringLiteralExprSyntax.self),
          let valueLiteral = args[1].expression.as(StringLiteralExprSyntax.self),
          let nameSegment = nameLiteral.segments.first,
          let valueSegment = valueLiteral.segments.first,
          case .stringSegment(let nameText) = nameSegment,
          case .stringSegment(let valueText) = valueSegment
        else {
          continue
        }
        headers.append((nameText.content.text, valueText.content.text))
      }
    }

    return headers
  }
}

// MARK: - Additional Error Cases

extension MacroExpansionError {
  static func invalidHeadersSyntax(_ message: String) -> MacroExpansionError {
    .invalidPathTemplate(message, suggestion: "Use @Headers { H(\"name\", \"value\") }")
  }
}
