import MacroTemplateKit
import SwiftSyntax
import SwiftSyntaxMacros
import SwiftDiagnostics

/// Macro implementation for @DELETE HTTP method.
///
/// Generates code for DELETE requests (typically for resource deletion).
///
/// Example:
/// ```swift
/// @DELETE("/users/{id}")
/// func deleteUser(id: String) async throws
/// ```
public struct DELETEMacro: PeerMacro, HTTPMacroExpansion {
  public static let config = HTTPMethodConfig.delete

  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    try sharedExpansion(of: node, providingPeersOf: declaration, in: context)
  }
}
