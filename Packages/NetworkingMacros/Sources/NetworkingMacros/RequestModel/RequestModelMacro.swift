import SwiftSyntax
import SwiftSyntaxMacros

/// Generates request members from property-level annotations.
public enum RequestModelMacro: MemberMacro {

  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard let structure = declaration.as(StructDeclSyntax.self) else {
      return emitRequiresStruct(node: node, context: context)
    }
    guard let input = RequestModelInput.parse(from: node, context: context) else { return [] }
    guard hasResponseAlias(in: structure, context: context) else { return [] }

    let properties = properties(in: structure, context: context)
    guard validate(properties: properties, context: context) else { return [] }
    return declarations(for: input, properties: properties, structure: structure)
  }
}
