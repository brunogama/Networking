import MacroTemplateKit
import SwiftSyntax
import SwiftSyntaxMacros
import SwiftDiagnostics

/// Macro implementation for @PATCH HTTP method.
///
/// Generates code for PATCH requests with partial update body support.
///
/// Example:
/// ```swift
/// @PATCH("/users/{id}")
/// @Body("updates")
/// func patchUser(id: String, updates: UserPatch) async throws -> User
/// ```
public struct PATCHMacro: PeerMacro, HTTPMacroExpansion {
  public static let config = HTTPMethodConfig.patch

  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    try sharedExpansion(of: node, providingPeersOf: declaration, in: context)
  }
}
