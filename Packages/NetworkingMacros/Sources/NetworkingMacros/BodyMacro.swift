import SwiftSyntax
import SwiftSyntaxMacros

/// Macro implementation for @Body attached macro.
///
/// The @Body macro is a "marker macro" that validates the body parameter exists
/// but doesn't generate any peer code. HTTP method macros (POST, PUT, PATCH) detect
/// this attribute and use it to generate body encoding code.
public struct BodyMacro: AccessorMacro, PeerMacro {
  /// Synthesizes the accessor for a request-model body property.
  public static func expansion(
    of _: AttributeSyntax,
    providingAccessorsOf declaration: some DeclSyntaxProtocol,
    in _: some MacroExpansionContext
  ) throws -> [AccessorDeclSyntax] {
    guard let variable = declaration.as(VariableDeclSyntax.self),
      let binding = variable.bindings.first,
      let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier
    else {
      return []
    }

    return [RequestModelSyntaxFactory.getter(from: .payload, property: name)]
  }

  /// Validates the annotation consumed by API generation.
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
      throw MacroExpansionError.invalidMacroApplication(
        "@Body can only be applied to functions"
      )
    }

    guard let paramName = extractBodyParameterName(from: node) else {
      throw MacroExpansionError.missingMacroArgument(
        "@Body requires parameter name: @Body(.parameter(\"parameterName\"))"
      )
    }

    try validateBodyParameter(named: paramName, in: funcDecl)

    let bodyMacroCount = countBodyMacros(on: funcDecl)
    guard bodyMacroCount <= 1 else {
      throw MacroExpansionError.multipleBodyMacros(
        "Only one @Body macro allowed per function. Found \(bodyMacroCount)."
      )
    }

    return []
  }

  // Extracts the parameter name from the Body attribute.
  private static func extractBodyParameterName(from node: AttributeSyntax) -> String? {
    guard case .argumentList(let arguments) = node.arguments,
      let firstArg = arguments.first,
      let parameterName = BoundaryExpressionParser.string(from: firstArg.expression)
    else {
      return nil
    }
    return parameterName
  }

  private static func validateBodyParameter(
    named paramName: String,
    in function: FunctionDeclSyntax
  ) throws {
    let paramNames = MacroHelpers.extractParameterNames(from: function)
    guard paramNames.contains(paramName) else {
      throw MacroExpansionError.bodyParameterNotFound(
        ParameterReference(paramName),
        available: paramNames.map { ParameterReference($0) }
      )
    }
  }

  private static func countBodyMacros(on function: FunctionDeclSyntax) -> Int {
    function.attributes.count { attribute in
      guard case .attribute(let bodyAttribute) = attribute,
        let identType = bodyAttribute.attributeName.as(IdentifierTypeSyntax.self)
      else {
        return false
      }
      return identType.name.text == "Body"
    }
  }
}

// MARK: - Additional Error Cases

extension MacroExpansionError {
  static func invalidMacroApplication(_ message: String) -> MacroExpansionError {
    // Reuse existing error type or create inline
    .invalidPathTemplate(EndpointPath(message), suggestion: nil)
  }

  static func missingMacroArgument(_ message: String) -> MacroExpansionError {
    .invalidPathTemplate(EndpointPath(message), suggestion: nil)
  }

  static func multipleBodyMacros(_ message: String) -> MacroExpansionError {
    .invalidPathTemplate(EndpointPath(message), suggestion: nil)
  }
}
