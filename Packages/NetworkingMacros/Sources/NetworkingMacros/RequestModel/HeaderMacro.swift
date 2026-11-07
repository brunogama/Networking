import SwiftSyntax
import SwiftSyntaxMacros

/// Synthesizes the accessor for a request-model header property.
public enum HeaderMacro: AccessorMacro {

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

    return [RequestModelSyntaxFactory.getter(from: .headerValues, property: name)]
  }
}
