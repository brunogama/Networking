import SwiftSyntax
import SwiftSyntaxMacros

public struct APIMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard let input = expansionInput(node: node, declaration: declaration, context: context) else {
      return []
    }

    let methods = try endpointImplementations(
      in: input.protocolDeclaration,
      accessLevel: input.accessLevel,
      context: context
    )
    return [
      makeImplementation(
        for: input.protocolDeclaration,
        baseURL: input.baseURL,
        accessLevel: input.accessLevel,
        methods: methods
      )
    ]
  }
}
