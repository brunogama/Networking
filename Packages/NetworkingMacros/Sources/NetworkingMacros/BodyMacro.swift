import SwiftSyntax
import SwiftSyntaxMacros

/// Macro implementation for @Body attached macro.
///
/// The @Body macro is a "marker macro" that validates the body parameter exists
/// but doesn't generate any peer code. HTTP method macros (POST, PUT, PATCH) detect
/// this attribute and use it to generate body encoding code.
public struct BodyMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    // 1. Validate macro is applied to a function
    guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
      throw MacroExpansionError.invalidMacroApplication(
        "@Body can only be applied to functions"
      )
    }

    // 2. Extract parameter name from macro argument
    guard let paramName = extractBodyParameterName(from: node) else {
      throw MacroExpansionError.missingMacroArgument(
        "@Body requires parameter name: @Body(\"parameterName\")"
      )
    }

    // 3. Get all parameter names from function signature
    let parameters = funcDecl.signature.parameterClause.parameters
    let paramNames = parameters.map { param in
      // Use secondName (internal name) if available, otherwise firstName (external name)
      param.secondName?.text ?? param.firstName.text
    }

    // 4. Validate parameter exists in function signature
    guard paramNames.contains(paramName) else {
      throw MacroExpansionError.bodyParameterNotFound(
        paramName,
        available: paramNames
      )
    }

    // 5. Check for multiple @Body macros on same function
    let bodyMacroCount = funcDecl.attributes.filter { attr in
      guard case .attribute(let attribute) = attr,
        let identType = attribute.attributeName.as(IdentifierTypeSyntax.self)
      else {
        return false
      }
      return identType.name.text == "Body"
    }.count

    if bodyMacroCount > 1 {
      throw MacroExpansionError.multipleBodyMacros(
        "Only one @Body macro allowed per function. Found \(bodyMacroCount)."
      )
    }

    // 6. @Body is a marker macro - return empty array
    // HTTP method macros will detect this attribute and use it
    return []
  }

  /// Extracts the parameter name from @Body("parameterName") attribute
  private static func extractBodyParameterName(from node: AttributeSyntax) -> String? {
    guard case .argumentList(let arguments) = node.arguments,
      let firstArg = arguments.first,
      let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self),
      let segment = stringLiteral.segments.first,
      case .stringSegment(let text) = segment
    else {
      return nil
    }
    return text.content.text
  }
}

// MARK: - Additional Error Cases

extension MacroExpansionError {
  static func invalidMacroApplication(_ message: String) -> MacroExpansionError {
    // Reuse existing error type or create inline
    .invalidPathTemplate(message, suggestion: nil)
  }

  static func missingMacroArgument(_ message: String) -> MacroExpansionError {
    .invalidPathTemplate(message, suggestion: nil)
  }

  static func multipleBodyMacros(_ message: String) -> MacroExpansionError {
    .invalidPathTemplate(message, suggestion: nil)
  }
}
