import SwiftSyntax
import SwiftSyntaxMacros

/// Generates a concrete client next to an `@API` protocol.
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
      accessLevel: input.accessLevel?.peerAccessLevel,
      context: context
    )
    return [
      makeImplementation(
        for: input.protocolDeclaration,
        baseURL: input.baseURL,
        accessLevel: input.accessLevel?.peerAccessLevel,
        methods: methods
      ),
      makeFactory(for: input.protocolDeclaration, accessLevel: input.accessLevel),
    ]
  }
}
